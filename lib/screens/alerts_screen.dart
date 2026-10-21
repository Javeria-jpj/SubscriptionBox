import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/notification_service.dart';
import 'package:subbox_app/services/subscription_service.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';

/// Needs action now: due within 3 days, overdue, or the price went up.
bool isUrgent(Subscription s) => s.daysLeft <= 3 || s.priceChange > 0;

/// Alerts tab: urgent items to triage, scheduled reminders, payment
/// history and reminder settings.
class AlertsView extends ConsumerStatefulWidget {
  const AlertsView({
    super.key,
    required this.subs,
    required this.payments,
    required this.settings,
    required this.onOpen,
  });

  final List<Subscription> subs;
  final List<PaidItem> payments;
  final ReminderSettings settings;
  final ValueChanged<Subscription> onOpen;

  @override
  ConsumerState<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends ConsumerState<AlertsView> {
  int _tab = 0; // 0 Urgent, 1 Scheduled, 2 History

  @override
  Widget build(BuildContext context) {
    final urgent = widget.subs.where(isUrgent).toList();
    final scheduled =
        NotificationService.plan(widget.subs, widget.settings, DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Summary(urgent: urgent),
        const SizedBox(height: 16),
        SegmentedButton(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text('Urgent (${urgent.length})')),
            ButtonSegment(
                value: 1, label: Text('Scheduled (${scheduled.length})')),
            const ButtonSegment(value: 2, label: Text('History')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: 16),
        ...switch (_tab) {
          0 => urgent.isEmpty
              ? [_empty('Nothing urgent. No renewals in the next 3 days.')]
              : [
                  for (final s in urgent)
                    _UrgentCard(sub: s, onOpen: widget.onOpen),
                ],
          1 => scheduled.isEmpty
              ? [
                  _empty(widget.settings.enabled
                      ? 'No upcoming reminders.'
                      : 'Reminders are turned off below.')
                ]
              : [
                  Panel(
                    child: Column(children: [
                      for (final r in scheduled.take(30))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ServiceIcon(
                              name: r.sub.name,
                              category: r.sub.category,
                              size: 36),
                          title: Text(r.sub.name, style: heading(14)),
                          subtitle: Text(
                            r.days == 0
                                ? 'Renewal day'
                                : '${r.days} day${r.days == 1 ? '' : 's'} before renewal',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          trailing: Text(
                            '${formatDate(r.at)}\n${formatHour(r.at.hour)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ]),
                  ),
                ],
          _ => widget.payments.isEmpty
              ? [_empty('No payments recorded yet.')]
              : [
                  Panel(
                    child: Column(children: [
                      for (final p in widget.payments.take(50))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => widget.onOpen(p.sub),
                          leading: ServiceIcon(
                              name: p.sub.name,
                              category: p.sub.category,
                              size: 36),
                          title: Text(p.sub.name, style: heading(14)),
                          subtitle: Text(
                              'Paid ${formatDate(p.payment.paidAt)}',
                              style: const TextStyle(color: AppColors.muted)),
                          trailing: Text(
                              formatMoney(
                                  p.payment.amount, p.payment.currency),
                              style: heading(14, color: AppColors.primary)),
                        ),
                    ]),
                  ),
                ],
        },
        const SizedBox(height: 16),
        _SettingsPanel(settings: widget.settings),
      ],
    );
  }

  Widget _empty(String text) => Panel(
        child: Row(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(text, style: const TextStyle(color: AppColors.muted))),
        ]),
      );
}

/// "3 Action Deadlines" header with the amount at risk.
class _Summary extends StatelessWidget {
  const _Summary({required this.urgent});

  final List<Subscription> urgent;

  @override
  Widget build(BuildContext context) {
    final due = urgent.where((s) => s.daysLeft <= 3).toList();
    final next = due.isEmpty ? null : due.first; // list is sorted by date
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.circle,
                size: 10,
                color: urgent.isEmpty ? AppColors.primary : AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${urgent.length} Action Deadline${urgent.length == 1 ? '' : 's'}',
                style: heading(20,
                    color: urgent.isEmpty ? AppColors.text : AppColors.error),
              ),
            ),
            if (urgent.isNotEmpty)
              const Tag('Triage required', color: AppColors.error),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('At-risk auto debits',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  FittedBox(
                    child: Text(
                        sumByCurrency(due, (s) => s.price, (s) => s.currency),
                        style: heading(30)),
                  ),
                ],
              ),
            ),
            if (next != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Next charge',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(
                  next.daysLeft <= 0
                      ? 'Today'
                      : next.daysLeft == 1
                          ? 'Tomorrow'
                          : formatDate(next.nextRenewal),
                  style: heading(15, color: AppColors.error),
                ),
              ]),
          ]),
        ],
      ),
    );
  }
}

class _UrgentCard extends ConsumerWidget {
  const _UrgentCard({required this.sub, required this.onOpen});

  final Subscription sub;
  final ValueChanged<Subscription> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = sub.daysLeft;
    final hike = sub.priceChange > 0;
    final when = d < 0
        ? 'Overdue'
        : d == 0
            ? 'Today'
            : d == 1
                ? 'Tomorrow'
                : 'In $d days';
    final money = formatMoney(sub.price, sub.currency);

    final String message;
    if (d <= 3) {
      message = sub.isTrial
          ? 'Free trial ends ${when.toLowerCase()} (${formatDate(sub.nextRenewal)}). '
              '$money will be charged automatically.'
          : d < 0
              ? 'Renewal was due ${formatDate(sub.nextRenewal)}. Mark it paid '
                  'or update the date.'
              : 'Auto-debit of $money scheduled for '
                  '${formatDate(sub.nextRenewal)}. Cancel before then to avoid '
                  'the charge.';
    } else {
      message = 'Price went up by '
          '${formatMoney(sub.priceChange, sub.currency)} per '
          '${sub.cycle.toLowerCase()} billing. Yearly impact: +'
          '${formatMoney(sub.priceChange * cycles[sub.cycle]!, sub.currency)}.';
    }
    final color = d <= 3 ? AppColors.error : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
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
                        sub.paymentMethod.isEmpty
                            ? sub.category
                            : sub.paymentMethod,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, spacing: 4,
                  children: [
                Text.rich(TextSpan(children: [
                  if (hike)
                    TextSpan(
                      text: '${formatMoney(sub.previousPrice!, sub.currency)} ',
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough),
                    ),
                  TextSpan(
                      text: money,
                      style: heading(16,
                          color: hike ? AppColors.warning : AppColors.text)),
                ])),
                Tag(
                  hike && d > 3
                      ? '+${(sub.priceChange / sub.previousPrice! * 100).toStringAsFixed(1)}% hike'
                      : '${sub.isTrial ? 'Ends' : 'Renews'} ${when.toLowerCase()}',
                  color: color,
                ),
              ]),
            ]),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(message, style: const TextStyle(fontSize: 13))),
              ]),
            ),
            if (d <= 3 && sub.cancelUrl.isNotEmpty)
              FilledButton.icon(
                onPressed: () => openCancelLink(context, sub.cancelUrl),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(sub.isTrial ? 'Cancel Trial Now' : 'Open Cancel Page'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              ),
            Row(spacing: 8, children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onOpen(sub),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Review'),
                  style: _outlined,
                ),
              ),
              Expanded(
                child: hike && d > 3
                    ? OutlinedButton.icon(
                        onPressed: () => ref
                            .read(subscriptionServiceProvider)
                            .acceptPrice(sub),
                        icon: const Icon(Icons.done, size: 18),
                        label: const Text('Accept New Rate'),
                        style: _outlined,
                      )
                    : OutlinedButton.icon(
                        onPressed: () => confirmMarkPaid(context, ref, sub),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Keep & Mark Paid'),
                        style: _outlined,
                      ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static final _outlined = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    foregroundColor: AppColors.text,
    side: const BorderSide(color: AppColors.border),
  );
}

/// Reminder on/off and the time of day reminders fire.
class _SettingsPanel extends ConsumerWidget {
  const _SettingsPanel({required this.settings});

  final ReminderSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void save(ReminderSettings s) =>
        ref.read(subscriptionServiceProvider).saveSettings(s);

    return Panel(
      title: 'Reminder Settings',
      trailing: Tag(settings.enabled ? 'Active' : 'Off',
          color: settings.enabled ? AppColors.primary : AppColors.muted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kIsWeb
                ? 'Phone notifications are sent by the Android/iOS app. '
                    'These settings sync to your phone.'
                : 'Notifications before each renewal, on the days chosen '
                    'per subscription.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Renewal reminders'),
            value: settings.enabled,
            onChanged: (v) =>
                save(ReminderSettings(enabled: v, hour: settings.hour)),
          ),
          Row(children: [
            const Expanded(child: Text('Reminder time')),
            DropdownButton<int>(
              value: settings.hour,
              underline: const SizedBox(),
              items: [
                for (var h = 6; h <= 22; h++)
                  DropdownMenuItem(value: h, child: Text(formatHour(h))),
              ],
              onChanged: settings.enabled
                  ? (h) => save(ReminderSettings(enabled: true, hour: h!))
                  : null,
            ),
          ]),
        ],
      ),
    );
  }
}
