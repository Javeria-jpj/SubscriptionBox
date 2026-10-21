import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/services/analytics.dart';
import 'package:subbox_app/services/auth_service.dart';
import 'package:subbox_app/services/subscription_service.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';
import 'package:subbox_app/screens/account_sheet.dart';
import 'package:subbox_app/screens/alerts_screen.dart';
import 'package:subbox_app/screens/analytics_screen.dart';
import 'package:subbox_app/screens/deadlines_screen.dart';
import 'package:subbox_app/screens/subscription_form_screen.dart';

/// Main screen after sign-in: navigation (bottom bar on phones, sidebar
/// on web) around the Dashboard, Deadlines, Add, Alerts and Analytics tabs.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _category; // null = show all
  String _search = '';
  int _tab = 0; // index into _tabs
  Subscription? _editing; // subscription open in the form (null = add new)

  /// Shows the add/edit form as a tab (navigation stays visible).
  void _openForm([Subscription? sub]) => setState(() {
        _tab = 2;
        _editing = sub;
      });

  void _selectTab(int i) => setState(() {
        _tab = i;
        _editing = null; // the Add tab opens a blank form
      });

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final payments = ref.watch(paymentsProvider).value ?? [];
    final cancelled = ref.watch(cancelledProvider).value ?? [];
    final settings =
        ref.watch(settingsProvider).value ?? const ReminderSettings();
    final user = ref.watch(userProvider).value;
    final all = subs.value ?? [];
    final wide = MediaQuery.sizeOf(context).width >= 900; // web / tablet
    final badges = {
      1: all.where((s) => s.daysLeft <= 1).length, // due within 24h
      3: all.where(isUrgent).length,
    };

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
          IconButton(
            tooltip: 'Alerts',
            onPressed: () => _selectTab(3),
            icon: Badge(
              isLabelVisible: badges[3]! > 0,
              label: Text('${badges[3]}'),
              backgroundColor: AppColors.danger,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          if (!wide)
            IconButton(
              tooltip: 'Account',
              onPressed: () => showAccountSheet(context),
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceHigh,
                child: Text(
                  (user?.displayName ?? '?').characters.firstOrNull
                          ?.toUpperCase() ??
                      '?',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: subs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Could not load your subscriptions',
          message: 'Check your internet connection and try again.\n($e)',
          action: FilledButton(
            onPressed: () => ref.invalidate(subscriptionsProvider),
            style: FilledButton.styleFrom(minimumSize: const Size(160, 46)),
            child: const Text('Retry'),
          ),
        ),
        data: (all) => switch (_tab) {
          1 => DeadlinesView(subs: all, onOpen: _openForm),
          2 => SubscriptionFormScreen(
              key: ValueKey(_editing?.id ?? 'new'),
              sub: _editing,
              onDone: () => _selectTab(0),
            ),
          3 => AlertsView(
              subs: all,
              payments: payments,
              settings: settings,
              onOpen: _openForm,
            ),
          4 => AnalyticsView(
              subs: all,
              payments: payments,
              cancelled: cancelled,
              onOpen: _openForm,
            ),
          _ => _Dashboard(
              all: all,
              cancelled: cancelled,
              category: _category,
              search: _search,
              onCategory: (c) => setState(() => _category = c),
              onSearch: (q) => setState(() => _search = q),
              onOpen: _openForm,
              onSeeInsights: () => _selectTab(4),
            ),
        },
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
                  i == 2
                      // Center "+" button, like the design.
                      ? NavigationDestination(
                          icon: const IconBox(Icons.add,
                              color: AppColors.primary, size: 40),
                          selectedIcon: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add,
                                color: AppColors.onPrimary),
                          ),
                          label: t.short,
                        )
                      : NavigationDestination(
                          icon: Badge(
                            isLabelVisible: (badges[i] ?? 0) > 0,
                            backgroundColor: AppColors.danger,
                            child: Icon(t.icon),
                          ),
                          label: t.short,
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
                    badges: badges,
                    user: user,
                    onSelect: _selectTab,
                    onAccount: () => showAccountSheet(context),
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
  (icon: Icons.dashboard_outlined, short: 'Dashboard', long: 'Dashboard'),
  (icon: Icons.alarm, short: 'Deadlines', long: 'Deadlines & Timers'),
  (icon: Icons.add, short: 'Add', long: 'Track Subscription'),
  (icon: Icons.crisis_alert, short: 'Alerts', long: 'Alerts & Cutoffs'),
  (icon: Icons.insights, short: 'Analytics', long: 'Analytics & Runway'),
];

/// Badge text and color for how soon a subscription renews.
(String, Color) renewalTag(Subscription s) {
  final d = s.daysLeft;
  final what = s.isTrial ? 'Trial ends' : 'Renews';
  if (d < 0) return ('Overdue', AppColors.error);
  if (d == 0) return ('$what today', AppColors.error);
  if (d == 1) return ('$what tomorrow', AppColors.error);
  return ('$what in $d days', d <= 3 ? AppColors.warning : AppColors.muted);
}

/// Dashboard tab: stats, due-soon alert, insights, runway, filters and list.
class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.all,
    required this.cancelled,
    required this.category,
    required this.search,
    required this.onCategory,
    required this.onSearch,
    required this.onOpen,
    required this.onSeeInsights,
  });

  final List<Subscription> all;
  final List<Cancellation> cancelled;
  final String? category;
  final String search;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onSearch;
  final ValueChanged<Subscription?> onOpen;
  final VoidCallback onSeeInsights;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No subscriptions yet',
        message: 'Track Netflix, Spotify, ChatGPT and more to see what you '
            'spend and get reminded before every renewal.',
        action: FilledButton.icon(
          onPressed: () => onOpen(null),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Track Your First Subscription'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
        ),
      );
    }

    final query = search.trim().toLowerCase();
    final shown = all
        .where((s) => category == null || s.category == category)
        .where((s) => s.name.toLowerCase().contains(query))
        .toList();
    final dueSoon = all.where((s) => s.daysLeft <= 3).toList();
    final insights = buildInsights(all, DateTime.now());

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;

        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            _CategoryChips(
                subs: all, selected: category, onSelected: onCategory),
            TextField(
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Search subscriptions',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('No subscriptions match.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted)),
              ),
            for (final s in shown)
              _SubscriptionCard(sub: s, onTap: () => onOpen(s)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => onOpen(null),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Track Another Subscription'),
            ),
          ],
        );

        final side = [
          _RunwayPanel(subs: all, onOpen: onOpen),
          if (insights.isNotEmpty)
            Panel(
              title: 'Optimization Insights',
              trailing: TextButton(
                  onPressed: onSeeInsights, child: const Text('See all')),
              child: Column(spacing: 10, children: [
                for (final i in insights.take(wide ? 3 : 2))
                  InsightCard(insight: i, onOpen: onOpen),
              ]),
            ),
          if (cancelled.isNotEmpty) _SavedPanel(cancelled: cancelled),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Stats(subs: all, dueSoon: dueSoon.length, wide: wide),
            if (dueSoon.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DueSoon(subs: dueSoon, onTap: onOpen),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: list),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 360,
                    child: Column(spacing: 16, children: side),
                  ),
                ],
              )
            else
              Column(spacing: 16, children: [...side, list]),
          ],
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.subs, required this.dueSoon, required this.wide});

  final List<Subscription> subs;
  final int dueSoon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final trials = subs.where((s) => s.isTrial).length;
    String total(int months) =>
        sumByCurrency(subs, (s) => s.monthlyCost * months, (s) => s.currency);

    return StatGrid(wide: wide, cards: [
      StatCard(
        'Monthly commitment',
        total(1),
        '/mo',
        footer: const Text(
          'Across all billing cycles',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
      StatCard(
        'Annualized run-rate',
        total(12),
        '/yr',
        footer: _CategoryBar(subs: subs),
      ),
      StatCard(
        'Active subscriptions',
        '${subs.length}',
        'active',
        footer: Text(
          '● $trials free trial${trials == 1 ? '' : 's'}',
          style: const TextStyle(color: AppColors.warning, fontSize: 12),
        ),
      ),
      StatCard(
        'Action required',
        '$dueSoon',
        'due',
        color: dueSoon > 0 ? AppColors.error : AppColors.text,
        footer: const Text(
          'Renewing within 3 days',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ]);
  }
}

/// Colored bar showing each category's share of the monthly cost.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.subs});

  final List<Subscription> subs;

  @override
  Widget build(BuildContext context) {
    final data = spendByCategory(subs);
    final total = data.fold(0.0, (sum, e) => sum + e.value);
    if (total == 0) {
      return const Text(
        'No data yet',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }
    return Tooltip(
      message: [
        for (final e in data) '${e.key}: ${(e.value / total * 100).round()}%',
      ].join('\n'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            for (final e in data)
              Expanded(
                // Shares in tenths of a percent, at least 1 so it's visible.
                flex: (e.value / total * 1000).round().clamp(1, 1000),
                child: Container(
                  height: 6,
                  color: (categories[e.key] ?? categories['Other']!).$2,
                ),
              ),
          ],
        ),
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

/// "Upcoming 7-Day Runway": every charge in the next week as a timeline.
class _RunwayPanel extends StatelessWidget {
  const _RunwayPanel({required this.subs, required this.onOpen});

  final List<Subscription> subs;
  final ValueChanged<Subscription> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final charges = [
      for (final s in subs)
        for (final d in s.chargesUntil(end)) (sub: s, date: d),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return Panel(
      title: 'Upcoming 7-Day Runway',
      trailing: Text(runway(subs, now), style: heading(16)),
      child: charges.isEmpty
          ? const Text('No charges in the next 7 days.',
              style: TextStyle(color: AppColors.muted))
          : Column(children: [
              for (final c in charges)
                InkWell(
                  onTap: () => onOpen(c.sub),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(Icons.circle,
                          size: 10, color: renewalTag(c.sub).$2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.sub.name,
                                overflow: TextOverflow.ellipsis,
                                style: heading(14)),
                            Text(formatDate(c.date).toUpperCase(),
                                style: labelStyle),
                          ],
                        ),
                      ),
                      Text(formatMoney(c.sub.price, c.sub.currency),
                          style: heading(14)),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

/// Money saved per year by cancelling subscriptions.
class _SavedPanel extends StatelessWidget {
  const _SavedPanel({required this.cancelled});

  final List<Cancellation> cancelled;

  @override
  Widget build(BuildContext context) => Panel(
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SAVED TO DATE', style: labelStyle),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text('${savedPerYear(cancelled)}/year',
                      style: heading(22, color: AppColors.primary)),
                ),
                Text(
                  'From ${cancelled.length} cancelled '
                  'subscription${cancelled.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const IconBox(Icons.account_balance_wallet_outlined,
              color: AppColors.primary),
        ]),
      );
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
                          color:
                              sub.isTrial ? AppColors.warning : AppColors.muted,
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
              spacing: 8,
              children: [
                Tag(tagText, color: tagColor),
                if (sub.priceChange > 0)
                  const Tag('Price up', color: AppColors.warning),
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
    required this.badges,
    required this.user,
    required this.onSelect,
    required this.onAccount,
  });

  final int selected;
  final Map<int, int> badges; // tab index -> count needing attention
  final User? user;
  final ValueChanged<int> onSelect;
  final VoidCallback onAccount;

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
                    t.icon,
                    color: i == selected ? AppColors.onPrimary : AppColors.text,
                  ),
                  title: Text(
                    t.long,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i == selected
                          ? AppColors.onPrimary
                          : AppColors.text,
                    ),
                  ),
                  trailing: (badges[i] ?? 0) > 0
                      ? Tag(
                          '${badges[i]} ${i == 1 ? 'critical' : 'urgent'}',
                          color: AppColors.error,
                        )
                      : null,
                ),
              ),
            ),
          const Spacer(),
          Material(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onAccount,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.background,
                      child: Text(
                        name.isEmpty
                            ? '?'
                            : name.characters.first.toUpperCase(),
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
                    const Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
