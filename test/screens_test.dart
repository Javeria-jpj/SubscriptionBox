import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:subbox_app/models/subscription.dart';
import 'package:subbox_app/screens/analytics_screen.dart';
import 'package:subbox_app/services/analytics.dart';
import 'package:subbox_app/theme.dart';
import 'package:subbox_app/widgets/app_widgets.dart';
import 'package:subbox_app/widgets/charts.dart';

final now = DateTime(2026, 10, 21);

Subscription sub(String name, double price,
        {String category = 'Entertainment',
        String currency = 'USD',
        int inDays = 10,
        double? previousPrice}) =>
    Subscription(
      id: name,
      name: name,
      category: category,
      price: price,
      currency: currency,
      cycle: 'Monthly',
      nextRenewal: DateTime.now().add(Duration(days: inDays)),
      previousPrice: previousPrice,
    );

/// Wraps [child] in the app theme at the given screen width.
Widget app(Widget child, {double width = 400}) => MaterialApp(
      theme: appTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  // Fonts are not downloaded in tests; the default font is used instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  final subs = [
    sub('Netflix', 15),
    sub('Spotify', 10),
    sub('YouTube Premium', 18.99, previousPrice: 13.99),
    sub('ChatGPT Plus', 20, category: 'Software & AI'),
    sub('Jazz', 1500, currency: 'PKR', category: 'Utilities'),
  ];

  Future<void> pumpAnalytics(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(
      AnalyticsView(
        subs: subs,
        payments: const [],
        cancelled: [
          Cancellation(
              name: 'Hulu', monthlyCost: 10, currency: 'USD', cancelledAt: now),
        ],
        onOpen: (_) {},
        now: now,
      ),
      width: width,
    ));
  }

  testWidgets('analytics shows totals, charts and insights (phone)',
      (tester) async {
    await pumpAnalytics(tester);
    expect(find.text('Analytics & Runway'), findsOneWidget);
    expect(find.text('\$63.99'), findsOneWidget); // monthly USD in donut
    expect(find.byType(DonutChart), findsOneWidget);
    expect(find.byType(BarChart), findsNWidgets(2));
    expect(find.textContaining('\$120.00 /yr', findRichText: true),
        findsOneWidget); // saved per year
    // Insights are below the fold.
    await tester.scrollUntilVisible(find.text('Smart Insights'), 300);
    expect(find.textContaining('YouTube Premium went up'), findsOneWidget);
  });

  testWidgets('analytics switches currency', (tester) async {
    await pumpAnalytics(tester);
    expect(find.widgetWithText(ChoiceChip, 'PKR'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'PKR'));
    await tester.pump();
    expect(find.text('Rs 1500.00'), findsWidgets);
  });

  testWidgets('analytics lays out on a wide (web) screen', (tester) async {
    await pumpAnalytics(tester, width: 1300);
    expect(tester.takeException(), isNull);
    expect(find.byType(StatCard), findsNWidgets(4));
  });

  testWidgets('analytics empty state', (tester) async {
    await tester.pumpWidget(app(AnalyticsView(
        subs: const [], payments: const [], cancelled: const [], onOpen: (_) {})));
    expect(find.text('No analytics yet'), findsOneWidget);
  });

  testWidgets('insight card opens its subscription', (tester) async {
    Subscription? opened;
    final insight = buildInsights([subs[2]], now)
        .firstWhere((i) => i.label == 'Price increase');
    await tester.pumpWidget(
        app(InsightCard(insight: insight, onOpen: (s) => opened = s)));
    await tester.tap(find.byType(InsightCard));
    expect(opened?.name, 'YouTube Premium');
  });
}
