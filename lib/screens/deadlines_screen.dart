import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';

/// Deadlines tab: upcoming renewals grouped by urgency, with a live
/// countdown for anything due within 24 hours.
class DeadlinesView extends ConsumerWidget {
  const DeadlinesView({super.key, required this.subs, required this.onOpen});

  final List<Subscription> subs; // already sorted by nextRenewal
  final ValueChanged<Subscription> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final critical = subs.where((s) => s.daysLeft <= 1).toList();
    final week = subs.where((s) => s.daysLeft >= 2 && s.daysLeft <= 7).toList();
    final later = subs.where((s) => s.daysLeft > 7).toList();
    final dueIn7 = [...critical, ...week];

    if (subs.isEmpty) {
      return const Center(
        child: Text('No renewals to track yet.',
            style: TextStyle(color: AppColors.muted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _RunwayCard(subs: dueIn7),
        if (critical.isNotEmpty) ...[
          const _Header('● CRITICAL · UNDER 24H', AppColors.warning,
              'Action recommended'),
          for (final s in critical)
            _DeadlineCard(sub: s, critical: true, onOpen: onOpen),
        ],
        if (week.isNotEmpty) ...[
          _Header('THIS WEEK (2 – 7 DAYS)', AppColors.text,
              '${week.length} subscription${week.length == 1 ? '' : 's'}'),
          for (final s in week) _DeadlineCard(sub: s, onOpen: onOpen),
        ],
        if (later.isNotEmpty) ...[
          const _Header('LATER', AppColors.text, 'More than a week away'),
          for (final s in later) _DeadlineCard(sub: s, onOpen: onOpen),
        ],
      ],
    );
  }
}

/// "7-Day Runway": how much will be charged in the next 7 days.
class _RunwayCard extends StatelessWidget {
  const _RunwayCard({required this.subs});

  final List<Subscription> subs;

  @override
  Widget build(BuildContext context) {
    final sums = <String, double>{};
    for (final s in subs) {
      sums[s.currency] = (sums[s.currency] ?? 0) + s.price;
    }
    final total = sums.isEmpty
        ? formatMoney(0, 'USD')
        : sums.entries.map((e) => formatMoney(e.value, e.key)).join(' + ');
    final trials = subs.where((s) => s.isTrial).length;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hourglass_bottom,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('IMMEDIATE OBLIGATION', style: labelStyle)),
            if (trials > 0)
              Tag('$trials trial${trials == 1 ? '' : 's'} ending',
                  color: AppColors.warning),
          ]),
          const SizedBox(height: 14),
          const Text('7-Day Runway', style: TextStyle(color: AppColors.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: total, style: heading(32)),
              TextSpan(
                  text: '  due across ${subs.length} service'
                      '${subs.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.muted)),
            ])),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.color, this.trailing);

  final String title;
  final Color color;
  final String trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: heading(17, color: color))),
          Text(trailing.toUpperCase(), style: labelStyle),
        ]),
      );
}

class _DeadlineCard extends ConsumerWidget {
  const _DeadlineCard(
      {required this.sub, required this.onOpen, this.critical = false});

  final Subscription sub;
  final ValueChanged<Subscription> onOpen;
  final bool critical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = sub.isTrial ? AppColors.error : AppColors.warning;
    final days = sub.daysLeft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onOpen(sub),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: critical ? Border(left: BorderSide(color: accent, width: 4)) : null,
          ),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  ServiceIcon(name: sub.name, category: sub.category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.name, style: heading(16)),
                        Text(
                          sub.isTrial
                              ? 'Free trial will charge ${formatMoney(sub.price, sub.currency)}'
                              : sub.paymentMethod.isNotEmpty
                                  ? 'Auto-renews via ${sub.paymentMethod}'
                                  : sub.category,
                          style: TextStyle(
                              color: sub.isTrial
                                  ? AppColors.error
                                  : AppColors.muted,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatMoney(sub.price, sub.currency),
                        style: heading(16)),
                    Text('/${sub.cycle.toLowerCase()}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 12),
                if (critical)
                  _Countdown(target: sub.nextRenewal, color: accent)
                else
                  Row(children: [
                    Tag(
                        'Renews in $days days (${formatDate(sub.nextRenewal)})',
                        color: days <= 3 ? AppColors.warning : AppColors.primary),
                  ]),
                const SizedBox(height: 12),
                Row(spacing: 8, children: [
                  if (sub.cancelUrl.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openCancelLink(context, sub.cancelUrl),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(sub.isTrial ? 'Cancel Trial' : 'Cancel Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => confirmMarkPaid(context, ref, sub),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark Paid'),
                      style:
                          FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live "13H 47M 19S LEFT" timer, updated every second.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.target, required this.color});

  final DateTime target;
  final Color color;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _timer =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer; // start ticking
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.target.difference(DateTime.now());
    final text = left.isNegative
        ? 'OVERDUE SINCE ${formatDate(widget.target).toUpperCase()}'
        : '${left.inHours}H ${left.inMinutes % 60}M ${left.inSeconds % 60}S LEFT';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.timer_outlined, color: widget.color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
        ),
        Text(formatDate(widget.target),
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }
}
