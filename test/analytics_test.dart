import 'package:flutter_test/flutter_test.dart';
import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/analytics.dart';
import 'package:subbox_app/services/notification_service.dart';
import 'package:subbox_app/utils/validators.dart';

final today = DateTime.now();

Subscription sub(
  String name, {
  double price = 10,
  String cycle = 'Monthly',
  String category = 'Entertainment',
  String currency = 'USD',
  int inDays = 10,
  DateTime? renewal,
  bool isTrial = false,
  double? previousPrice,
  List<int> reminders = const [3, 1, 0],
}) =>
    Subscription(
      name: name,
      category: category,
      price: price,
      currency: currency,
      cycle: cycle,
      nextRenewal: renewal ?? today.add(Duration(days: inDays)),
      isTrial: isTrial,
      previousPrice: previousPrice,
      reminders: reminders,
    );

Payment paid(double amount, DateTime at) =>
    Payment(amount: amount, currency: 'USD', paidAt: at, forRenewal: at);

void main() {
  group('spending', () {
    test('main currency is the most used one', () {
      expect(mainCurrency([]), 'USD');
      expect(
          mainCurrency([
            sub('A', currency: 'PKR'),
            sub('B', currency: 'PKR'),
            sub('C'),
          ]),
          'PKR');
    });

    test('spend by category, biggest first, in monthly terms', () {
      final data = spendByCategory([
        sub('Netflix', price: 15),
        sub('Spotify', price: 10),
        sub('AWS', price: 120, cycle: 'Yearly', category: 'Utilities'),
      ]);
      expect(data.map((e) => e.key), ['Entertainment', 'Utilities']);
      expect(data[0].value, 25);
      expect(data[1].value, 10);
    });

    test('12-month projection follows each billing cycle', () {
      final from = DateTime(2026, 1, 1);
      final data = projectedSpend([
        sub('Monthly', price: 10, renewal: DateTime(2026, 1, 15)),
        sub('Yearly', price: 100, cycle: 'Yearly', renewal: DateTime(2026, 3, 1)),
        sub('Quarterly', price: 30, cycle: 'Quarterly', renewal: DateTime(2026, 2, 10)),
      ], from);
      expect(data.length, 12);
      expect(data.first.month, DateTime(2026, 1));
      expect(data[0].amount, 10); // Jan: monthly only
      expect(data[1].amount, 40); // Feb: monthly + quarterly
      expect(data[2].amount, 110); // Mar: monthly + yearly
      expect(data[4].amount, 40); // May: monthly + quarterly
      expect(data.fold(0.0, (s, m) => s + m.amount), 120 + 100 + 120);
    });

    test('projection skips charges before this month (overdue)', () {
      final data = projectedSpend(
          [sub('Old', renewal: DateTime(2025, 12, 20))], DateTime(2026, 1, 5),
          months: 2);
      expect(data[0].amount, 10); // Jan 20
      expect(data[1].amount, 10); // Feb 20
    });

    test('paid by month groups payments into the last 6 months', () {
      final now = DateTime(2026, 10, 21);
      final data = paidByMonth([
        paid(10, DateTime(2026, 10, 1)),
        paid(5, DateTime(2026, 10, 20)),
        paid(7, DateTime(2026, 5, 3)),
        paid(99, DateTime(2026, 4, 30)), // older than 6 months
      ], now);
      expect(data.first.month, DateTime(2026, 5));
      expect(data.last.amount, 15);
      expect(data.first.amount, 7);
      expect(data.fold(0.0, (s, m) => s + m.amount), 22);
    });

    test('7-day runway counts weekly plans more than once', () {
      final now = DateTime(2026, 10, 1);
      expect(
          runway([
            sub('Weekly', price: 5, cycle: 'Weekly', renewal: DateTime(2026, 10, 1, 12)),
            sub('Later', price: 50, renewal: DateTime(2026, 10, 20)),
          ], now, days: 8),
          '\$10.00');
    });

    test('totals per currency are never mixed', () {
      expect(
          sumByCurrency([sub('A'), sub('B', currency: 'PKR', price: 1500)],
              (s) => s.price, (s) => s.currency),
          '\$10.00 + Rs 1500.00');
    });
  });

  group('insights', () {
    List<String> labels(List<Subscription> subs) =>
        buildInsights(subs, today).map((i) => i.label).toList();

    test('no insights for a single cheap subscription', () {
      expect(labels([sub('Cheap', price: 3, category: 'Utilities')]), isEmpty);
    });

    test('trial converting within 3 days is high priority', () {
      final list = buildInsights(
          [sub('Figma', isTrial: true, inDays: 1, category: 'Software & AI')],
          today);
      expect(list.first.label, 'Trial converting');
      expect(list.first.severity, Severity.high);
    });

    test('price increase with yearly impact', () {
      final i = buildInsights(
              [sub('YouTube', price: 18.99, previousPrice: 13.99)], today)
          .firstWhere((i) => i.label == 'Price increase');
      expect(i.yearlyImpact, '+\$60.00/yr');
      expect(i.title, contains('35.7%'));
    });

    test('price drop is not reported as an increase', () {
      expect(labels([sub('X', price: 5, previousPrice: 9)]),
          isNot(contains('Price increase')));
    });

    test('overdue renewal', () {
      expect(labels([sub('Gym', inDays: -2, category: 'Fitness')]),
          contains('Overdue'));
    });

    test('annual billing tip for the two priciest monthly plans', () {
      final tips = buildInsights([
        sub('A', price: 50, category: 'Utilities'),
        sub('B', price: 40, category: 'Fitness'),
        sub('C', price: 30, category: 'Education'),
      ], today)
          .where((i) => i.label == 'Billing tip')
          .toList();
      expect(tips.map((i) => i.sub!.name), ['A', 'B']);
      expect(tips.first.yearlyImpact, 'Save ~\$100.00/yr');
    });

    test('overlap: 2 entertainment services in the same currency', () {
      final i = buildInsights([
        sub('Netflix', price: 15),
        sub('Disney+', price: 5),
      ], today)
          .firstWhere((i) => i.label == 'Overlap');
      expect(i.yearlyImpact, 'Save up to \$60.00/yr');
      expect(labels([sub('Netflix'), sub('Hulu', currency: 'PKR')]),
          isNot(contains('Overlap')));
    });

    test('big spender above 40% of the budget', () {
      expect(
          labels([
            sub('Adobe', price: 60, category: 'Software & AI'),
            sub('A', price: 5, category: 'Utilities'),
            sub('B', price: 5, category: 'Fitness'),
          ]),
          contains('Big spender'));
    });

    test('most urgent first', () {
      final list = buildInsights([
        sub('Adobe', price: 60, category: 'Software & AI'),
        sub('Trial', isTrial: true, inDays: 0, category: 'Utilities'),
      ], today);
      expect(list.first.severity, Severity.high);
      expect(list.last.severity, Severity.tip);
    });

    test('saved per year from cancelled subscriptions', () {
      expect(
          savedPerYear([
            Cancellation(
                name: 'Hulu', monthlyCost: 10, currency: 'USD', cancelledAt: today),
            Cancellation(
                name: 'Max', monthlyCost: 5, currency: 'USD', cancelledAt: today),
          ]),
          '\$180.00');
    });
  });

  group('csv export', () {
    test('header, rows and escaping', () {
      final csv = toCsv([sub('Netflix, 4K "Premium"', price: 22.99)]);
      final lines = csv.split('\n');
      expect(lines.first, startsWith('Name,Category,Price'));
      expect(lines[1], startsWith('"Netflix, 4K ""Premium""",Entertainment,22.99'));
    });

    test('formula injection is neutralised', () {
      expect(toCsv([sub('=HYPERLINK("x")')]).split('\n')[1],
          startsWith('"\'=HYPERLINK'));
    });
  });

  group('reminders', () {
    final now = DateTime(2026, 10, 1, 12);

    test('one reminder per chosen day, at the chosen hour, soonest first', () {
      final plan = NotificationService.plan(
          [sub('Netflix', renewal: DateTime(2026, 10, 10))],
          const ReminderSettings(hour: 8),
          now);
      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 7, 8),
        DateTime(2026, 10, 9, 8),
        DateTime(2026, 10, 10, 8),
      ]);
    });

    test('past reminders are skipped', () {
      final plan = NotificationService.plan(
          [sub('Soon', renewal: DateTime(2026, 10, 2))],
          const ReminderSettings(),
          now);
      expect(plan.map((r) => r.days), [0]); // 1 day before = today 9 AM, passed
    });

    test('turned off = nothing scheduled', () {
      expect(
          NotificationService.plan([sub('A', renewal: DateTime(2026, 12, 1))],
              const ReminderSettings(enabled: false), now),
          isEmpty);
    });

    test('settings read safely from Firestore data', () {
      expect(ReminderSettings.fromMap(null).hour, 9);
      expect(ReminderSettings.fromMap({'hour': 3}).hour, 6);
      expect(ReminderSettings.fromMap({'enabled': false}).enabled, false);
    });
  });

  group('validators', () {
    test('price', () {
      expect(validatePrice('9.99'), isNull);
      expect(validatePrice('10'), isNull);
      expect(validatePrice('0'), isNotNull);
      expect(validatePrice('-5'), isNotNull);
      expect(validatePrice('abc'), isNotNull);
      expect(validatePrice('1.999'), isNotNull);
      expect(validatePrice('99999999'), isNotNull);
    });

    test('service name', () {
      expect(validateServiceName('Netflix'), isNull);
      expect(validateServiceName('   '), isNotNull);
      expect(validateServiceName('x' * 61), isNotNull);
    });

    test('payment label rejects full card numbers', () {
      expect(validatePaymentLabel('Visa ••8841'), isNull);
      expect(validatePaymentLabel(''), isNull);
      expect(validatePaymentLabel('4111 1111 1111 1111'), isNotNull);
      expect(validatePaymentLabel('4111-1111-1111-1111'), isNotNull);
    });

    test('cancel url allows web links only', () {
      expect(validateUrl(''), isNull);
      expect(validateUrl('netflix.com/cancelplan'), isNull);
      expect(validateUrl('https://www.netflix.com/cancelplan'), isNull);
      expect(validateUrl('javascript:alert(1)'), isNotNull);
      expect(validateUrl('file:///etc/passwd'), isNotNull);
      expect(validateUrl('not a url'), isNotNull);
    });
  });

  test('charge dates until a given day', () {
    final s = sub('W', cycle: 'Weekly', renewal: DateTime(2026, 10, 1));
    expect(s.chargesUntil(DateTime(2026, 10, 16)), [
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 8),
      DateTime(2026, 10, 15),
    ]);
  });
}
