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

  /// Price converted to a per-month amount, e.g. $120/year -> $10/month.
  double get monthlyCost => price * cycles[cycle]! / 12;

  int get daysLeft {
    final now = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(nextRenewal).difference(now).inDays;
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
      };
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
