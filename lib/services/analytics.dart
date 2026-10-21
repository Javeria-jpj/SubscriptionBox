import 'package:flutter/material.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/theme.dart';

/// Expense analytics and smart insights. Pure functions over the data,
/// so they are easy to unit test. Amounts are never converted between
/// currencies: callers pass subscriptions of one currency at a time.

/// The currency used by most subscriptions (USD when there are none).
String mainCurrency(List<Subscription> subs) {
  final counts = <String, int>{};
  for (final s in subs) {
    counts[s.currency] = (counts[s.currency] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'USD';
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// Monthly cost per category, biggest first.
List<MapEntry<String, double>> spendByCategory(List<Subscription> subs) {
  final sums = <String, double>{};
  for (final s in subs) {
    sums[s.category] = (sums[s.category] ?? 0) + s.monthlyCost;
  }
  return sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// What will actually be charged in each of the next [months] calendar
/// months (starting with the month of [from]), following every billing
/// cycle. A yearly plan shows up only in the month it renews.
List<({DateTime month, double amount})> projectedSpend(
    List<Subscription> subs, DateTime from,
    {int months = 12}) {
  final start = DateTime(from.year, from.month);
  final totals = List.filled(months, 0.0);
  for (final s in subs) {
    for (final d in s.chargesUntil(DateTime(start.year, start.month + months))) {
      final i = (d.year - start.year) * 12 + d.month - start.month;
      if (i >= 0) totals[i] += s.price;
    }
  }
  return [
    for (var i = 0; i < months; i++)
      (month: DateTime(start.year, start.month + i), amount: totals[i]),
  ];
}

/// Total paid in each of the last [months] calendar months, oldest first.
List<({DateTime month, double amount})> paidByMonth(
    List<Payment> payments, DateTime now,
    {int months = 6}) {
  final first = DateTime(now.year, now.month - months + 1);
  final totals = List.filled(months, 0.0);
  for (final p in payments) {
    final i = (p.paidAt.year - first.year) * 12 + p.paidAt.month - first.month;
    if (i >= 0 && i < months) totals[i] += p.amount;
  }
  return [
    for (var i = 0; i < months; i++)
      (month: DateTime(first.year, first.month + i), amount: totals[i]),
  ];
}

/// How much charges total in the next [days] days, per currency.
String runway(List<Subscription> subs, DateTime now, {int days = 7}) {
  final end = now.add(Duration(days: days));
  final charges = [
    for (final s in subs)
      for (final _ in s.chargesUntil(end)) s,
  ];
  return sumByCurrency(charges, (s) => s.price, (s) => s.currency);
}

/// How urgent an insight is; also decides its color and sort order.
enum Severity {
  high(AppColors.error),
  medium(AppColors.warning),
  tip(AppColors.primary);

  const Severity(this.color);
  final Color color;
}

class Insight {
  const Insight({
    required this.severity,
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    this.sub,
    this.yearlyImpact,
  });

  final Severity severity;
  final String label; // short uppercase tag, e.g. "PRICE INCREASE"
  final String title;
  final String body;
  final IconData icon;
  final Subscription? sub; // the subscription to open, if any
  final String? yearlyImpact; // e.g. "+$60.00/yr" or "Save ~$40.00/yr"
}

/// Annual plans usually cost about 10 months of the monthly price.
const annualDiscountMonths = 2;

/// Rule-based suggestions for saving money, most urgent first.
List<Insight> buildInsights(List<Subscription> subs, DateTime now) {
  final out = <Insight>[];
  String money(double v, String c) => formatMoney(v, c);

  for (final s in subs) {
    final d = s.daysLeft;
    if (d < 0) {
      out.add(Insight(
        severity: Severity.high,
        label: 'Overdue',
        title: '${s.name} renewal date has passed',
        body: 'It was due on ${formatDate(s.nextRenewal)}. Mark it as paid, '
            'or update the date if you cancelled.',
        icon: Icons.error_outline,
        sub: s,
      ));
    } else if (s.isTrial && d <= 3) {
      out.add(Insight(
        severity: Severity.high,
        label: 'Trial converting',
        title: '${s.name} trial ends ${d == 0 ? 'today' : 'in $d day${d == 1 ? '' : 's'}'}',
        body: 'It turns into a paid plan at ${money(s.price, s.currency)}'
            '/${s.cycle.toLowerCase()}. Cancel now if you won\'t keep it.',
        icon: Icons.hourglass_bottom,
        sub: s,
        yearlyImpact: '${money(s.monthlyCost * 12, s.currency)}/yr at stake',
      ));
    }

    if (s.priceChange > 0) {
      final pct = s.priceChange / s.previousPrice! * 100;
      out.add(Insight(
        severity: Severity.medium,
        label: 'Price increase',
        title: '${s.name} went up ${pct.toStringAsFixed(1)}%',
        body: 'From ${money(s.previousPrice!, s.currency)} to '
            '${money(s.price, s.currency)} per ${s.cycle.toLowerCase()} '
            'billing. Consider a cheaper plan or pausing it.',
        icon: Icons.trending_up,
        sub: s,
        yearlyImpact:
            '+${money(s.priceChange * cycles[s.cycle]!, s.currency)}/yr',
      ));
    }
  }

  // Monthly plans worth switching to annual billing (two most expensive).
  final monthly = subs
      .where((s) => s.cycle == 'Monthly' && !s.isTrial && s.price >= 8)
      .toList()
    ..sort((a, b) => b.price.compareTo(a.price));
  for (final s in monthly.take(2)) {
    out.add(Insight(
      severity: Severity.tip,
      label: 'Billing tip',
      title: 'Pay ${s.name} yearly',
      body: 'Annual plans often include about $annualDiscountMonths months '
          'free. Check if ${s.name} offers one.',
      icon: Icons.savings_outlined,
      sub: s,
      yearlyImpact:
          'Save ~${money(s.price * annualDiscountMonths, s.currency)}/yr',
    ));
  }

  // Several services in the same category, e.g. 3 streaming apps.
  // Only compares subscriptions in the same currency.
  final groups = <(String, String), List<Subscription>>{};
  for (final s in subs) {
    (groups[(s.category, s.currency)] ??= []).add(s);
  }
  for (final MapEntry(key: (category, currency), value: list)
      in groups.entries) {
    if (list.length < (category == 'Entertainment' ? 2 : 3)) continue;
    if (category == 'Other') continue;
    final total = list.fold(0.0, (sum, s) => sum + s.monthlyCost);
    // Paying for only the priciest one at a time saves the rest.
    final priciest =
        list.map((s) => s.monthlyCost).reduce((a, b) => a > b ? a : b);
    out.add(Insight(
      severity: Severity.tip,
      label: 'Overlap',
      title: '${list.length} $category services',
      body: '${list.map((s) => s.name).join(', ')} cost '
          '${money(total, currency)}/mo together. Rotating them (one at a '
          'time) avoids paying for all at once.',
      icon: Icons.layers_outlined,
      yearlyImpact:
          'Save up to ${money((total - priciest) * 12, currency)}/yr',
    ));
  }

  // One subscription takes a big share of the budget.
  for (final currency in {for (final s in subs) s.currency}) {
    final list = subs.where((s) => s.currency == currency).toList();
    if (list.length < 3) continue;
    final total = list.fold(0.0, (sum, s) => sum + s.monthlyCost);
    final top = list.reduce((a, b) => a.monthlyCost >= b.monthlyCost ? a : b);
    final share = top.monthlyCost / total;
    if (share >= 0.4) {
      out.add(Insight(
        severity: Severity.medium,
        label: 'Big spender',
        title: '${top.name} is ${(share * 100).round()}% of your spending',
        body: 'It costs ${money(top.monthlyCost, currency)}/mo out of '
            '${money(total, currency)}/mo. Make sure you use it enough.',
        icon: Icons.pie_chart_outline,
        sub: top,
      ));
    }
  }

  out.sort((a, b) => a.severity.index.compareTo(b.severity.index));
  return out;
}

/// "Saved to date": yearly cost of every cancelled subscription.
String savedPerYear(List<Cancellation> cancelled) =>
    sumByCurrency(cancelled, (c) => c.monthlyCost * 12, (c) => c.currency);

/// Subscriptions as CSV (for export / spreadsheets).
String toCsv(List<Subscription> subs) {
  String cell(Object v) {
    final text = '$v';
    // Quote values with commas/quotes, and neutralise spreadsheet formulas.
    final safe = RegExp(r'^[=+\-@]').hasMatch(text) ? "'$text" : text;
    return safe.contains(RegExp('[",\n]'))
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  return [
    'Name,Category,Price,Currency,Cycle,Monthly cost,Next renewal,Trial,Payment method',
    for (final s in subs)
      [
        s.name,
        s.category,
        s.price.toStringAsFixed(2),
        s.currency,
        s.cycle,
        s.monthlyCost.toStringAsFixed(2),
        formatDate(s.nextRenewal),
        s.isTrial ? 'Yes' : 'No',
        s.paymentMethod,
      ].map(cell).join(','),
  ].join('\n');
}
