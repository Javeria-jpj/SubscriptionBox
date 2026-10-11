import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Category name -> (icon, color).
const categories = <String, (IconData, Color)>{
  'Entertainment': (Icons.movie_outlined, Color(0xFFF87171)),
  'Software & AI': (Icons.smart_toy_outlined, Color(0xFF4EDEA3)),
  'Productivity': (Icons.edit_note, Color(0xFFFFB95F)),
  'Utilities': (Icons.bolt, Color(0xFF60A5FA)),
  'Fitness': (Icons.fitness_center, Color(0xFFF472B6)),
  'Education': (Icons.school_outlined, Color(0xFFC0C1FF)),
  'Other': (Icons.category_outlined, Color(0xFF94A3B8)),
};

/// Billing cycle -> how many times it is charged per year.
const cycles = <String, double>{
  'Weekly': 52,
  'Monthly': 12,
  'Quarterly': 4,
  'Yearly': 1,
};

const currencies = ['USD', 'PKR', 'EUR', 'GBP'];

/// Reminder options: days before renewal -> label.
const reminderOptions = <int, String>{
  7: '7 days before',
  3: '3 days before',
  1: '1 day before',
  0: 'On the day',
};

/// Popular services for one-tap "fast fill" on the add screen.
const presets = [
  (name: 'Netflix', category: 'Entertainment', price: 15.49, logo: 'netflix'),
  (name: 'Spotify', category: 'Entertainment', price: 10.99, logo: 'spotify'),
  (name: 'ChatGPT Plus', category: 'Software & AI', price: 20.00, logo: 'chatgpt'),
  (name: 'YouTube Premium', category: 'Entertainment', price: 13.99, logo: 'youtube'),
  (name: 'Figma', category: 'Software & AI', price: 15.00, logo: 'figma'),
  (name: 'Adobe CC', category: 'Software & AI', price: 54.99, logo: 'adobe'),
  (name: 'GitHub Copilot', category: 'Software & AI', price: 10.00, logo: 'github_copilot'),
  (name: 'Notion Plus', category: 'Productivity', price: 12.00, logo: 'notion'),
  (name: 'Disney+', category: 'Entertainment', price: 13.99, logo: 'disney'),
  (name: 'iCloud+', category: 'Utilities', price: 2.99, logo: 'icloud'),
  (name: 'Gym', category: 'Fitness', price: 30.00, logo: 'gym'),
];

/// Logo image for a service name, or null. Matches the brand anywhere in
/// the name, so "Netflix 4K Premium" still gets assets/icons/netflix.png.
String? logoFor(String name) {
  final text = name.toLowerCase();
  for (final p in presets) {
    final brand = p.logo.split('_').first; // github_copilot -> github
    if (text.contains(brand)) return 'assets/icons/${p.logo}.png';
  }
  return null;
}

class Subscription {
  Subscription({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.currency,
    required this.cycle,
    required this.nextRenewal,
    this.isTrial = false,
    this.paymentMethod = '',
    this.cancelUrl = '',
    this.reminders = const [3, 1, 0],
  });

  final String? id; // null until saved to Firestore
  final String name;
  final String category;
  final double price;
  final String currency;
  final String cycle;
  final DateTime nextRenewal;
  final bool isTrial;
  final String paymentMethod;
  final String cancelUrl;
  final List<int> reminders; // days before renewal to notify

  /// Price converted to a per-month amount, e.g. $120/year -> $10/month.
  double get monthlyCost => price * cycles[cycle]! / 12;

  int get daysLeft {
    final now = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(nextRenewal).difference(now).inDays;
  }

  /// The renewal date one billing cycle after [nextRenewal],
  /// e.g. Jan 31 + 1 month = Feb 28 (day is clamped to the month's length).
  DateTime get nextCycleDate {
    final d = nextRenewal;
    if (cycle == 'Weekly') return d.add(const Duration(days: 7));
    final months = {'Monthly': 1, 'Quarterly': 3, 'Yearly': 12}[cycle]!;
    final firstOfMonth = DateTime(d.year, d.month + months);
    final lastDay =
        DateUtils.getDaysInMonth(firstOfMonth.year, firstOfMonth.month);
    return DateTime(firstOfMonth.year, firstOfMonth.month,
        d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
  }

  factory Subscription.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Subscription(
      id: doc.id,
      name: d['name'],
      category: d['category'],
      price: (d['price'] as num).toDouble(),
      currency: d['currency'],
      cycle: d['cycle'],
      nextRenewal: (d['nextRenewal'] as Timestamp).toDate(),
      isTrial: d['isTrial'] ?? false,
      paymentMethod: d['paymentMethod'] ?? '',
      cancelUrl: d['cancelUrl'] ?? '',
      reminders: List<int>.from(d['reminders'] ?? const [3, 1, 0]),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'price': price,
        'currency': currency,
        'cycle': cycle,
        'nextRenewal': Timestamp.fromDate(nextRenewal),
        'isTrial': isTrial,
        'paymentMethod': paymentMethod,
        'cancelUrl': cancelUrl,
        'reminders': reminders,
      };
}

/// One recorded payment, stored at
/// `users/{uid}/subscriptions/{subId}/payments/{id}`.
class Payment {
  const Payment({
    required this.amount,
    required this.currency,
    required this.paidAt,
    required this.forRenewal,
  });

  final double amount;
  final String currency;
  final DateTime paidAt; // when the user marked it paid
  final DateTime forRenewal; // the renewal date this payment covered

  factory Payment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Payment(
      amount: (d['amount'] as num).toDouble(),
      currency: d['currency'],
      paidAt: (d['paidAt'] as Timestamp).toDate(),
      forRenewal: (d['forRenewal'] as Timestamp).toDate(),
    );
  }
}

String formatMoney(double amount, String currency) {
  const symbols = {'USD': '\$', 'PKR': 'Rs ', 'EUR': '€', 'GBP': '£'};
  return '${symbols[currency] ?? '$currency '}${amount.toStringAsFixed(2)}';
}

String formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
