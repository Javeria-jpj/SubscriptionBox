import 'package:flutter_test/flutter_test.dart';
import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/utils/validators.dart';

Subscription sub(String cycle, double price, DateTime renewal) => Subscription(
      name: 'Test',
      category: 'Other',
      price: price,
      currency: 'USD',
      cycle: cycle,
      nextRenewal: renewal,
    );

void main() {
  test('validators', () {
    expect(validateEmail('bad'), isNotNull);
    expect(validateEmail('user@example.com'), isNull);
    expect(validatePassword('123'), isNotNull);
    expect(validatePassword('123456'), isNull);
    expect(validateName('Javeria'), isNull);
  });

  test('monthly cost per billing cycle', () {
    final now = DateTime.now();
    expect(sub('Monthly', 10, now).monthlyCost, 10);
    expect(sub('Yearly', 120, now).monthlyCost, 10);
    expect(sub('Quarterly', 30, now).monthlyCost, 10);
    expect(sub('Weekly', 12, now).monthlyCost, 52);
  });

  test('days left until renewal', () {
    final now = DateTime.now();
    expect(sub('Monthly', 1, now).daysLeft, 0);
    expect(sub('Monthly', 1, now.add(const Duration(days: 5))).daysLeft, 5);
    expect(sub('Monthly', 1, now.subtract(const Duration(days: 2))).daysLeft, -2);
  });

  test('logo matching', () {
    expect(logoFor('Netflix 4K Premium'), 'assets/icons/netflix.png');
    expect(logoFor('GitHub Copilot'), 'assets/icons/github_copilot.png');
    expect(logoFor('My Gym'), 'assets/icons/gym.png');
    expect(logoFor('Electricity'), isNull);
  });

  test('formatting', () {
    expect(formatMoney(12, 'USD'), '\$12.00');
    expect(formatMoney(1500, 'PKR'), 'Rs 1500.00');
    expect(formatDate(DateTime(2026, 10, 4)), 'Oct 4, 2026');
  });
}
