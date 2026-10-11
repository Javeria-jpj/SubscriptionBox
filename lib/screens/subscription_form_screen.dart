import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/subscription_service.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';

/// Add a new subscription, or edit/delete an existing one when [sub] is given.
/// Shown as a tab inside Home, so the navigation stays visible.
/// Two columns on wide screens (web), one column on phones.
class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({super.key, this.sub, required this.onDone});

  final Subscription? sub;

  /// Called after save, delete, mark-paid or cancel (Home goes back to the dashboard).
  final VoidCallback onDone;

  @override
  ConsumerState<SubscriptionFormScreen> createState() =>
      _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState
    extends ConsumerState<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.sub?.name);
  late final _price =
      TextEditingController(text: widget.sub?.price.toStringAsFixed(2));
  late final _payment = TextEditingController(text: widget.sub?.paymentMethod);
  late final _cancelUrl = TextEditingController(text: widget.sub?.cancelUrl);
  late String _category = widget.sub?.category ?? categories.keys.first;
  late String _currency = widget.sub?.currency ?? 'USD';
  late String _cycle = widget.sub?.cycle ?? 'Monthly';
  late DateTime _renewal =
      widget.sub?.nextRenewal ?? DateTime.now().add(const Duration(days: 30));
  late bool _isTrial = widget.sub?.isTrial ?? false;
  late final Set<int> _reminders = {...widget.sub?.reminders ?? const [3, 1, 0]};
  bool _saving = false;

  bool get _isEdit => widget.sub != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _renewal = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(subscriptionServiceProvider).save(Subscription(
            id: widget.sub?.id,
            name: _name.text.trim(),
            category: _category,
            price: double.parse(_price.text),
            currency: _currency,
            cycle: _cycle,
            nextRenewal: _renewal,
            isTrial: _isTrial,
            paymentMethod: _payment.text.trim(),
            cancelUrl: _cancelUrl.text.trim(),
            reminders: _reminders.toList()..sort((a, b) => b - a),
          ));
      widget.onDone();
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e');
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${widget.sub!.name}?'),
        content: const Text('This subscription will be removed permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(subscriptionServiceProvider).delete(widget.sub!.id!);
    widget.onDone();
  }

  // ---------- Sections ----------

  Widget _presets() => Panel(
        title: 'Fast-Fill Presets',
        trailing: const Text('Tap to auto-fill',
            style: TextStyle(color: AppColors.primary, fontSize: 12)),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in presets)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() {
                _name.text = p.name;
                _category = p.category;
                _price.text = p.price.toStringAsFixed(2);
              }),
              child: Container(
                width: 96,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _name.text == p.name
                          ? AppColors.primary
                          : AppColors.border),
                ),
                child: Column(children: [
                  ServiceIcon(name: p.name, category: p.category, size: 36),
                  const SizedBox(height: 8),
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                  Text('\$${p.price.toStringAsFixed(2)}/mo',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ]),
              ),
            ),
        ]),
      );

  Widget _service() => Panel(
        title: 'Service Identification',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('SERVICE NAME'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'e.g. Notion, OpenAI, AWS',
                prefixIcon: Icon(Icons.layers_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a service name' : null,
            ),
            const _Label('CATEGORY'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in categories.keys)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ]),
            const _Label('PAYMENT METHOD (OPTIONAL)'),
            TextFormField(
              controller: _payment,
              decoration: const InputDecoration(
                hintText: 'e.g. Visa ••8841',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
          ],
        ),
      );

  Widget _billing() => Panel(
        title: 'Billing Cadence',
        trailing: const Tag('Recurring'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('BILLING AMOUNT'),
                    TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: heading(18),
                      decoration: const InputDecoration(
                        prefixIcon:
                            Icon(Icons.attach_money, color: AppColors.primary),
                      ),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'Enter a valid amount'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('CURRENCY'),
                    DropdownButtonFormField(
                      initialValue: _currency,
                      items: [
                        for (final c in currencies)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ],
                ),
              ),
            ]),
            const _Label('CYCLE FREQUENCY'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton(
                showSelectedIcon: false,
                segments: [
                  for (final c in cycles.keys)
                    ButtonSegment(value: c, label: Text(c)),
                ],
                selected: {_cycle},
                onSelectionChanged: (s) => setState(() => _cycle = s.first),
              ),
            ),
            const _Label('NEXT RENEWAL DATE'),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined,
                      color: AppColors.primary),
                ),
                child: Text(formatDate(_renewal), style: heading(16)),
              ),
            ),
          ],
        ),
      );

  Widget _trial() => Panel(
        child: Column(children: [
          Row(children: [
            const IconBox(Icons.hourglass_bottom, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This is a Free Trial', style: heading(16)),
                  const Text('Renewal date = when the trial converts',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: _isTrial,
              onChanged: (v) => setState(() => _isTrial = v),
            ),
          ]),
          if (_isTrial)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.verified_user_outlined,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SubBox will flag this trial before it converts '
                    'into a paid subscription.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ]),
            ),
        ]),
      );

  Widget _alerts() => Panel(
        title: 'Renewal Alerts',
        trailing: const Tag('Reminders'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Phone notification at 9:00 AM before each renewal.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in reminderOptions.entries)
                FilterChip(
                  avatar: Icon(
                      _reminders.contains(o.key)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: _reminders.contains(o.key)
                          ? AppColors.onPrimary
                          : AppColors.muted),
                  label: Text(o.value),
                  selected: _reminders.contains(o.key),
                  onSelected: (on) => setState(() =>
                      on ? _reminders.add(o.key) : _reminders.remove(o.key)),
                ),
            ]),
          ],
        ),
      );

  /// Payment history + "Mark as Paid" (edit mode only).
  late final _paymentStream = _isEdit
      ? ref.read(subscriptionServiceProvider).watchPayments(widget.sub!.id!)
      : null;

  Widget _payments() => Panel(
        title: 'Payments',
        trailing: Tag('Due ${formatDate(widget.sub!.nextRenewal)}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () async {
                if (await confirmMarkPaid(context, ref, widget.sub!)) {
                  widget.onDone(); // renewal date changed
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                  'Mark as Paid · ${formatMoney(widget.sub!.price, widget.sub!.currency)}'),
            ),
            const _Label('PAYMENT HISTORY'),
            StreamBuilder(
              stream: _paymentStream,
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Text('No payments recorded yet.',
                      style: TextStyle(color: AppColors.muted));
                }
                final total = list.fold(0.0, (sum, p) => sum + p.amount);
                return Column(children: [
                  for (final p in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long,
                          color: AppColors.primary),
                      title: Text('Renewal ${formatDate(p.forRenewal)}'),
                      subtitle: Text('Paid ${formatDate(p.paidAt)}',
                          style: const TextStyle(color: AppColors.muted)),
                      trailing: Text(formatMoney(p.amount, p.currency),
                          style: heading(15)),
                    ),
                  const Divider(color: AppColors.border),
                  Row(children: [
                    Text('Total paid · ${list.length} payment${list.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppColors.muted)),
                    const Spacer(),
                    Text(formatMoney(total, list.first.currency),
                        style: heading(16, color: AppColors.primary)),
                  ]),
                ]);
              },
            ),
          ],
        ),
      );

  Widget _cancellation() => Panel(
        title: 'Cancellation Link',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('ONE-CLICK CANCELLATION URL (OPTIONAL)'),
            TextFormField(
              controller: _cancelUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://notion.so/billing/cancel',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Keep the cancel page handy for when you want out.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final left = [_isEdit ? _payments() : _presets(), _service()];
    final right = [_billing(), _trial(), _alerts(), _cancellation()];
    const gap = SizedBox(height: 16);

    return Form(
        key: _formKey,
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Tag('Subscription setup')),
              const SizedBox(height: 8),
              Text(_isEdit ? 'Edit Subscription' : 'Add New Subscription',
                  style: heading(wide ? 34 : 26)),
              const SizedBox(height: 4),
              const Text(
                'Track costs, billing cycles and renewal dates to avoid '
                'unwanted charges.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(spacing: 16, children: left)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(spacing: 16, children: right)),
                ])
              else
                Column(spacing: 16, children: [...left, ...right]),
              gap,
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_isEdit)
                    OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        minimumSize: const Size(140, 52),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: widget.onDone,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(140, 52)),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(
                    width: wide ? 320 : double.infinity,
                    child: SubmitButton(
                      label: _isEdit ? 'Save Changes' : 'Save Subscription',
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: labelStyle),
      );
}
