import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/analytics.dart';
import 'package:subbox_app/services/subscription_service.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';
import 'package:subbox_app/widgets/charts.dart';

/// Analytics tab: spending by category, 12-month projection, payment
/// history, biggest costs and smart insights. Charts show one currency at
/// a time (amounts are never converted between currencies).
class AnalyticsView extends StatefulWidget {
  const AnalyticsView({
    super.key,
    required this.subs,
    required this.payments,
    required this.cancelled,
    required this.onOpen,
    this.now,
  });

  final List<Subscription> subs;
  final List<PaidItem> payments;
  final List<Cancellation> cancelled;
  final ValueChanged<Subscription> onOpen;
  final DateTime? now; // fixed "today" for tests

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String? _currency; // null = the most used currency

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final allCurrencies = {for (final s in widget.subs) s.currency};
    final currency = allCurrencies.contains(_currency)
        ? _currency!
        : mainCurrency(widget.subs);
    final subs = widget.subs.where((s) => s.currency == currency).toList();
    final payments = [
      for (final p in widget.payments)
        if (p.payment.currency == currency) p.payment,
    ];
    String money(double v) => formatMoney(v, currency);

    if (widget.subs.isEmpty) {
      return const EmptyState(
        icon: Icons.insights,
        title: 'No analytics yet',
        message: 'Add a subscription to see where your money goes.',
      );
    }

    final monthly = subs.fold(0.0, (sum, s) => sum + s.monthlyCost);
    final paidTotal = payments.fold(0.0, (sum, p) => sum + p.amount);
    final insights = buildInsights(widget.subs, now);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      Widget pair(Widget a, Widget b) => wide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [Expanded(child: a), Expanded(child: b)],
              ),
            )
          : Column(spacing: 16, children: [a, b]);

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            Expanded(
              child: Text('Analytics & Runway', style: heading(wide ? 30 : 24)),
            ),
            IconButton(
              tooltip: 'Copy as CSV (paste into a spreadsheet)',
              icon: const Icon(Icons.download_outlined),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: toCsv(widget.subs)));
                if (context.mounted) {
                  showMessage(context, 'Copied ${widget.subs.length} '
                      'subscriptions as CSV. Paste into Excel or Sheets.');
                }
              },
            ),
          ]),
          const Text('Where your money goes, and where it is going next.',
              style: TextStyle(color: AppColors.muted)),
          if (allCurrencies.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final c in allCurrencies)
                ChoiceChip(
                  label: Text(c),
                  selected: c == currency,
                  onSelected: (_) => setState(() => _currency = c),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          StatGrid(wide: wide, cards: [
            StatCard('Monthly run-rate', money(monthly), '/mo',
                footer: _muted('${subs.length} active in $currency')),
            StatCard('Projected annual', money(monthly * 12), '/yr',
                footer: _muted('If nothing changes')),
            StatCard(
                'Average cost',
                money(subs.isEmpty ? 0 : monthly / subs.length),
                '/mo',
                footer: _muted('Per subscription')),
            StatCard('Saved to date', savedPerYear(widget.cancelled), '/yr',
                color: AppColors.primary,
                footer: _muted('From ${widget.cancelled.length} cancelled '
                    'subscription${widget.cancelled.length == 1 ? '' : 's'}')),
          ]),
          const SizedBox(height: 16),
          pair(
            _CategoryPanel(subs: subs, money: money),
            _ProjectionPanel(subs: subs, now: now, money: money),
          ),
          const SizedBox(height: 16),
          pair(
            _HistoryPanel(
                payments: payments, now: now, total: paidTotal, money: money),
            _TopCostsPanel(subs: subs, money: money, onOpen: widget.onOpen),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'Smart Insights',
            trailing: Tag('${insights.length} found'),
            child: insights.isEmpty
                ? _muted('Looking good! No savings opportunities right now.')
                : Column(spacing: 12, children: [
                    for (final i in insights)
                      InsightCard(insight: i, onOpen: widget.onOpen),
                  ]),
          ),
        ],
      );
    });
  }
}

Widget _muted(String text) => Text(text,
    style: const TextStyle(color: AppColors.muted, fontSize: 12));

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.subs, required this.money});

  final List<Subscription> subs;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final data = spendByCategory(subs);
    final total = data.fold(0.0, (sum, e) => sum + e.value);
    Color color(String c) => (categories[c] ?? categories['Other']!).$2;

    return Panel(
      title: 'Spending by Category',
      trailing: const Tag('Monthly'),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DonutChart(
            values: [for (final e in data) e.value],
            colors: [for (final e in data) color(e.key)],
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(money(total), style: heading(18)),
              const Text('per month',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ]),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in data)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.circle, size: 10, color: color(e.key)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key)),
                      Text(money(e.value), style: heading(13)),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(e.value / total * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionPanel extends StatelessWidget {
  const _ProjectionPanel(
      {required this.subs, required this.now, required this.money});

  final List<Subscription> subs;
  final DateTime now;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final data = projectedSpend(subs, now);
    final total = data.fold(0.0, (sum, m) => sum + m.amount);
    final peak = data.reduce((a, b) => b.amount > a.amount ? b : a);

    return Panel(
      title: '12-Month Cash Flow',
      trailing: Tag('Peak ${monthName(peak.month)}', color: AppColors.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: money(total), style: heading(22)),
            const TextSpan(
                text: '  charged over the next 12 months',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
          const SizedBox(height: 16),
          BarChart(
            values: [for (final m in data) m.amount],
            labels: [for (final m in data) monthName(m.month)[0]],
            format: money,
            highlight: {0},
            color: const Color(0xFFC0C1FF),
          ),
          const SizedBox(height: 8),
          _muted('Yearly and quarterly plans show up in the month they renew. '
              'Highlighted bar = this month.'),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.payments,
    required this.now,
    required this.total,
    required this.money,
  });

  final List<Payment> payments;
  final DateTime now;
  final double total;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final data = paidByMonth(payments, now);
    final thisMonth = data.last.amount;
    final lastMonth = data[data.length - 2].amount;
    final diff = thisMonth - lastMonth;

    return Panel(
      title: 'Payment History',
      trailing: const Tag('Last 6 months'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: money(thisMonth), style: heading(22)),
            const TextSpan(
                text: '  paid this month',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
          if (lastMonth > 0 || thisMonth > 0)
            Text(
              '${diff > 0 ? '▲' : diff < 0 ? '▼' : '='} '
              '${money(diff.abs())} vs last month',
              style: TextStyle(
                  color: diff > 0 ? AppColors.warning : AppColors.primary,
                  fontSize: 12),
            ),
          const SizedBox(height: 16),
          BarChart(
            values: [for (final m in data) m.amount],
            labels: [for (final m in data) monthName(m.month)],
            format: money,
          ),
          const SizedBox(height: 8),
          _muted(payments.isEmpty
              ? 'Tap "Mark Paid" on a renewal to start your history.'
              : '${payments.length} payments recorded · ${money(total)} in total'),
        ],
      ),
    );
  }
}

class _TopCostsPanel extends StatelessWidget {
  const _TopCostsPanel(
      {required this.subs, required this.money, required this.onOpen});

  final List<Subscription> subs;
  final String Function(double) money;
  final ValueChanged<Subscription> onOpen;

  @override
  Widget build(BuildContext context) {
    final top = [...subs]..sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
    final max = top.isEmpty ? 0.0 : top.first.monthlyCost;

    return Panel(
      title: 'Biggest Costs',
      trailing: const Tag('Per month'),
      child: Column(children: [
        for (final s in top.take(5))
          InkWell(
            onTap: () => onOpen(s),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                ServiceIcon(name: s.name, category: s.category, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(s.name,
                              overflow: TextOverflow.ellipsis,
                              style: heading(14)),
                        ),
                        Text(money(s.monthlyCost), style: heading(14)),
                      ]),
                      MeterBar(
                        value: s.monthlyCost,
                        max: max,
                        color: (categories[s.category] ??
                                categories['Other']!)
                            .$2,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// One smart insight: colored tag, title, explanation and yearly impact.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight, required this.onOpen});

  final Insight insight;
  final ValueChanged<Subscription> onOpen;

  @override
  Widget build(BuildContext context) {
    final color = insight.severity.color;
    final sub = insight.sub;
    return InkWell(
      onTap: sub == null ? null : () => onOpen(sub),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(children: [
              Icon(insight.icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Tag(insight.label, color: color).alignLeft()),
              if (insight.yearlyImpact != null)
                Text(insight.yearlyImpact!,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
            ]),
            Text(insight.title, style: heading(15)),
            Text(insight.body,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget alignLeft() => Align(alignment: Alignment.centerLeft, child: this);
}
