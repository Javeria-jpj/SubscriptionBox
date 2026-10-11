import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/auth_service.dart';
import 'package:subbox_app/services/subscription_service.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';
import 'package:subbox_app/screens/deadlines_screen.dart';
import 'package:subbox_app/screens/subscription_form_screen.dart';

/// Subscriptions dashboard: stat cards, due-soon alert, filters and list.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _category; // null = show all
  int _tab = 0; // index into _tabs: 0 Dashboard, 1 Deadlines, 2 Subscriptions
  Subscription? _editing; // subscription open in the form (null = add new)

  /// Shows the add/edit form as the Subscriptions tab (navigation stays visible).
  void _openForm([Subscription? sub]) => setState(() {
    _tab = 2;
    _editing = sub;
  });

  void _selectTab(int i) => setState(() {
    _tab = i;
    _editing = null; // the Subscriptions tab opens a blank "add" form
  });

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final user = ref.watch(userProvider).value;
    final wide = MediaQuery.sizeOf(context).width >= 900; // web / tablet
    final critical = (subs.value ?? []).where((s) => s.daysLeft <= 1).length;
    void signOut() => ref.read(authServiceProvider).signOut();

    final page = Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        // On web the logo lives in the sidebar instead.
        title: wide
            ? null
            : Row(
                children: [
                  const AppLogo(size: 30),
                  const SizedBox(width: 10),
                  Text('SubBox', style: heading(20)),
                ],
              ),
        actions: [
          if (wide)
            FilledButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Track Subscription'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            ),
          _NotificationBell(
            dueSoon: (subs.value ?? []).where((s) => s.daysLeft <= 3).toList(),
            onTap: _openForm,
          ),
          if (!wide)
            PopupMenuButton(
              tooltip: 'Account',
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceHigh,
                child: Text(
                  (user?.displayName ?? '?').characters.first.toUpperCase(),
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '${user?.displayName ?? ''}\n${user?.email ?? ''}',
                  ),
                ),
                PopupMenuItem(onTap: signOut, child: const Text('Sign out')),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: subs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (all) => _tab == 2
            ? SubscriptionFormScreen(
                key: ValueKey(_editing?.id ?? 'new'),
                sub: _editing,
                onDone: () => _selectTab(0),
              )
            : _tab == 1
            ? DeadlinesView(subs: all, onOpen: _openForm)
            : LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 900;
                  final shown = _category == null
                      ? all
                      : all.where((s) => s.category == _category).toList();
                  final dueSoon = all.where((s) => s.daysLeft <= 3).toList();
                  final cardWidth = wide
                      ? (box.maxWidth - 32 - 12) / 2
                      : box.maxWidth;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _Stats(subs: all, dueSoon: dueSoon.length, wide: wide),
                      if (dueSoon.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DueSoon(subs: dueSoon, onTap: _openForm),
                      ],
                      const SizedBox(height: 20),
                      _CategoryChips(
                        subs: all,
                        selected: _category,
                        onSelected: (c) => setState(() => _category = c),
                      ),
                      const SizedBox(height: 16),
                      if (shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No subscriptions yet.\nTrack your first one below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final s in shown)
                            SizedBox(
                              width: cardWidth,
                              child: _SubscriptionCard(
                                sub: s,
                                onTap: () => _openForm(s),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _openForm,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Track Another Subscription'),
                      ),
                    ],
                  );
                },
              ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primaryDark.withValues(alpha: 0.25),
              destinations: [
                for (final (i, t) in _tabs.indexed)
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: i == 1 && critical > 0,
                      backgroundColor: AppColors.danger,
                      child: Icon(t.$1),
                    ),
                    label: t.$2,
                  ),
              ],
            ),
    );

    // Android back button: return to the dashboard instead of closing the app.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(0);
      },
      child: !wide
          ? page
          : Scaffold(
              body: Row(
                children: [
                  _SideBar(
                    selected: _tab,
                    critical: critical,
                    user: user,
                    onSelect: _selectTab,
                    onSignOut: signOut,
                  ),
                  Expanded(child: page),
                ],
              ),
            ),
    );
  }
}

/// Navigation tabs, shared by the phone bottom bar and the web sidebar.
const _tabs = [
  (Icons.dashboard_outlined, 'Dashboard'),
  (Icons.alarm, 'Deadlines'),
  (Icons.receipt_long, 'Subscriptions'),
];

/// Bell with a count badge; opens a sheet listing renewals due soon.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.dueSoon, required this.onTap});

  final List<Subscription> dueSoon;
  final ValueChanged<Subscription> onTap;

  void _showAlerts(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        Text('Notifications', style: heading(20)),
        const SizedBox(height: 8),
        if (dueSoon.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'You\'re all caught up. No renewals in the next 3 days.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final s in dueSoon)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ServiceIcon(name: s.name, category: s.category),
            title: Text(s.name, style: heading(15)),
            subtitle: Text(
              formatMoney(s.price, s.currency),
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: Tag(renewalTag(s).$1, color: renewalTag(s).$2),
            onTap: () {
              Navigator.pop(sheet);
              onTap(s);
            },
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notifications',
    onPressed: () => _showAlerts(context),
    icon: Badge(
      isLabelVisible: dueSoon.isNotEmpty,
      label: Text('${dueSoon.length}'),
      backgroundColor: AppColors.danger,
      child: const Icon(Icons.notifications_outlined),
    ),
  );
}

/// Badge text and color for how soon a subscription renews.
(String, Color) renewalTag(Subscription s) {
  final d = s.daysLeft;
  final what = s.isTrial ? 'Trial ends' : 'Renews';
  if (d < 0) return ('Overdue', AppColors.error);
  if (d == 0) return ('$what today', AppColors.error);
  if (d == 1) return ('$what tomorrow', AppColors.error);
  return ('$what in $d days', d <= 3 ? AppColors.warning : AppColors.muted);
}

/// Totals per currency, e.g. "$27.99 + Rs 1500.00".
String totals(List<Subscription> subs, {int months = 1}) {
  final sums = <String, double>{};
  for (final s in subs) {
    sums[s.currency] = (sums[s.currency] ?? 0) + s.monthlyCost * months;
  }
  if (sums.isEmpty) return formatMoney(0, 'USD');
  return sums.entries.map((e) => formatMoney(e.value, e.key)).join(' + ');
}

class _Stats extends StatelessWidget {
  const _Stats({required this.subs, required this.dueSoon, required this.wide});

  final List<Subscription> subs;
  final int dueSoon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final trials = subs.where((s) => s.isTrial).length;
    final cards = [
      _StatCard(
        'Monthly commitment',
        totals(subs),
        '/mo',
        footer: const Text(
          'Across all billing cycles',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
      _StatCard(
        'Annualized run-rate',
        totals(subs, months: 12),
        '/yr',
        footer: _CategoryBar(subs: subs),
      ),
      _StatCard(
        'Active subscriptions',
        '${subs.length}',
        'active',
        footer: Text(
          '● $trials free trial${trials == 1 ? '' : 's'}',
          style: const TextStyle(color: AppColors.warning, fontSize: 12),
        ),
      ),
      _StatCard(
        'Action required',
        '$dueSoon',
        'due',
        color: dueSoon > 0 ? AppColors.error : AppColors.text,
        footer: const Text(
          'Renewing within 3 days',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ];

    // Rows of 2 (phone) or 4 (web). Cards grow to fit their text, and
    // IntrinsicHeight keeps cards in the same row equally tall.
    final perRow = wide ? 4 : 2;
    return Column(
      spacing: 12,
      children: [
        for (var i = 0; i < cards.length; i += perRow)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final card in cards.skip(i).take(perRow))
                  Expanded(child: card),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
    this.label,
    this.value,
    this.suffix, {
    required this.footer,
    this.color = AppColors.text,
  });

  final String label, value, suffix;
  final Widget footer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: heading(28, color: color),
                  ),
                  TextSpan(
                    text: ' $suffix',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

/// Colored bar showing how many subscriptions are in each category.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.subs});

  final List<Subscription> subs;

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) {
      return const Text(
        'No data yet',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          for (final c in categories.entries)
            if (subs.any((s) => s.category == c.key))
              Expanded(
                flex: subs.where((s) => s.category == c.key).length,
                child: Container(height: 6, color: c.value.$2),
              ),
        ],
      ),
    );
  }
}

/// Red alert panel listing renewals within 3 days.
class _DueSoon extends StatelessWidget {
  const _DueSoon({required this.subs, required this.onTap});

  final List<Subscription> subs;
  final ValueChanged<Subscription> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1215),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(Icons.bolt, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${subs.length} renewal${subs.length == 1 ? '' : 's'} due soon',
                      style: heading(18),
                    ),
                    const Text(
                      'Review before automatic charges post',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in subs)
            InkWell(
              onTap: () => onTap(s),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: renewalTag(s).$2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: s.name, style: heading(15)),
                            TextSpan(
                              text: '  ${formatMoney(s.price, s.currency)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tag(renewalTag(s).$1, color: renewalTag(s).$2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.subs,
    required this.selected,
    required this.onSelected,
  });

  final List<Subscription> subs;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String? category, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == category,
        onSelected: (_) => onSelected(category),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(null, 'All (${subs.length})'),
          for (final c in categories.keys)
            if (subs.any((s) => s.category == c))
              chip(c, '$c (${subs.where((s) => s.category == c).length})'),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub, required this.onTap});

  final Subscription sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (tagText, tagColor) = renewalTag(sub);
    final subtitle = sub.isTrial
        ? 'Free trial period'
        : sub.paymentMethod.isNotEmpty
        ? sub.paymentMethod
        : sub.category;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Panel(
        child: Column(
          children: [
            Row(
              children: [
                ServiceIcon(name: sub.name, category: sub.category),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        style: heading(17),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: sub.isTrial
                              ? AppColors.warning
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(sub.price, sub.currency),
                      style: heading(17),
                    ),
                    Text(
                      '/${sub.cycle.toLowerCase()}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Tag(tagText, color: tagColor),
                const Spacer(),
                Text(
                  formatDate(sub.nextRenewal),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Left navigation for wide screens (web), like the SubBox web design.
class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.selected,
    required this.critical,
    required this.user,
    required this.onSelect,
    required this.onSignOut,
  });

  final int selected;
  final int critical; // renewals due within 24h
  final User? user;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';
    return Container(
      width: 250,
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: Row(
              children: [
                const AppLogo(size: 30),
                const SizedBox(width: 10),
                Text('SubBox', style: heading(20)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text('PORTFOLIO NAVIGATION', style: labelStyle),
          ),
          for (final (i, t) in _tabs.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: i == selected
                    ? AppColors.primaryDark
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  onTap: () => onSelect(i),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    t.$1,
                    color: i == selected ? AppColors.onPrimary : AppColors.text,
                  ),
                  title: Text(
                    t.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i == selected
                          ? AppColors.onPrimary
                          : AppColors.text,
                    ),
                  ),
                  trailing: i == 1 && critical > 0
                      ? Tag('$critical critical', color: AppColors.error)
                      : null,
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.background,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: heading(14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  icon: const Icon(
                    Icons.logout,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
