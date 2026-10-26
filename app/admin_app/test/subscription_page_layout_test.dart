import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription_metrics.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/models/subscription_filter.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_page_body.dart';

AdminSubscription _subscription(int index) => AdminSubscription(
  id: 's$index',
  customerName: 'Customer $index',
  customerEmail: 'customer$index@example.com',
  planNameAr: 'الخطة الذهبية',
  planNameEn: 'Gold plan',
  planPrice: 120,
  currencyCode: 'SAR',
  status: index == 3 ? 'pending_payment' : 'active',
  startsAt: DateTime(2026, 1, index),
  endsAt: index == 2
      ? DateTime.now().add(const Duration(days: 4))
      : DateTime.now().add(const Duration(days: 30)),
  cupsEntitled: 20,
  cupsUsed: index,
  cupsReserved: 0,
  autoRenew: index.isEven,
);

Finder _label(String text) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == text);

void _setViewport(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<AdminSubscription> subscriptions,
  String search = '',
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  final metrics = AdminSubscriptionMetrics.from(subscriptions);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: SubscriptionPageBody(
          subscriptions: subscriptions,
          metrics: metrics,
          search: search,
          onSearchChanged: (_) {},
          onOpen: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a narrow page shows cards, metrics and pagination', (
    tester,
  ) async {
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      subscriptions: [
        for (var index = 1; index <= 9; index++) _subscription(index),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptions), findsOneWidget);
    expect(find.text(S.subscriptionsActiveMetric), findsOneWidget);
    expect(find.text(S.subscriptionsRowsLabel(1, 8, 9)), findsOneWidget);
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Customer 9'), findsNothing);
  });

  testWidgets('a wide page shows the table columns', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      subscriptions: [
        for (var index = 1; index <= 4; index++) _subscription(index),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionsColumnCustomer), findsOneWidget);
    expect(find.text(S.subscriptionsColumnPlan), findsOneWidget);
    expect(find.text(S.subscriptionsColumnCups), findsOneWidget);
    expect(find.text(S.subscriptionsColumnPeriod), findsOneWidget);
    expect(find.text(S.subscriptionsColumnLastUsed), findsOneWidget);
  });

  testWidgets('the search hides the rows that do not match', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      subscriptions: [
        for (var index = 1; index <= 4; index++) _subscription(index),
      ],
      search: 'Customer 2',
    );

    expect(_label('Customer 2'), findsOneWidget);
    expect(_label('Customer 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status filter keeps only the matching rows', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      subscriptions: [
        for (var index = 1; index <= 4; index++) _subscription(index),
      ],
    );

    await tester.tap(find.byTooltip(S.subscriptionsFilter));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        PopupMenuItem<SubscriptionFilter>,
        S.subscriptionsFilterPending,
      ),
    );
    await tester.pumpAndSettle();

    expect(_label('Customer 3'), findsOneWidget);
    expect(_label('Customer 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty page shows the empty state', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, subscriptions: const []);

    expect(find.text(S.noSubscriptions), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a search with no result offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(
      tester,
      subscriptions: [_subscription(1)],
      search: 'missing',
    );

    expect(find.text(S.subscriptionsNoMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      subscriptions: [
        for (var index = 1; index <= 3; index++) _subscription(index),
      ],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptions), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1280, 900);
    await _pumpPage(
      tester,
      subscriptions: [
        for (var index = 1; index <= 3; index++) _subscription(index),
      ],
      dark: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionsColumnCustomer), findsOneWidget);
  });
}
