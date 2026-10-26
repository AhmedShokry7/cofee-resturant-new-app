import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan_metrics.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/models/subscription_plan_filter.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_page_body.dart';

AdminSubscriptionPlan _plan(
  int index, {
  bool isActive = true,
  bool isForSale = true,
}) => AdminSubscriptionPlan(
  id: 'p$index',
  code: 'PLAN_$index',
  nameAr: 'باقة $index',
  nameEn: 'Plan $index',
  price: 100.0 + index,
  currencyCode: 'SAR',
  durationDays: 30,
  cupsPerCycle: 10,
  isActive: isActive,
  isForSale: isForSale,
  subscribersCount: index,
  activeSubscribers: index > 1 ? index - 1 : 0,
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
  required List<AdminSubscriptionPlan> plans,
  String search = '',
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  final metrics = AdminSubscriptionPlanMetrics.from(plans);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: SubscriptionPlanPageBody(
          plans: plans,
          metrics: metrics,
          search: search,
          onSearchChanged: (_) {},
          onAdd: () {},
          onEdit: (_) {},
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
      plans: [for (var index = 1; index <= 9; index++) _plan(index)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionPlans), findsOneWidget);
    expect(find.text(S.subscriptionPlansTotalMetric), findsOneWidget);
    expect(find.text(S.subscriptionPlanAddAction), findsOneWidget);
    expect(find.text(S.subscriptionPlansRowsLabel(1, 8, 9)), findsOneWidget);
    expect(find.text('Plan 1'), findsOneWidget);
    expect(find.text('Plan 9'), findsNothing);
  });

  testWidgets('a wide page shows the table columns', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      plans: [for (var index = 1; index <= 4; index++) _plan(index)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionPlansColumnPlan), findsOneWidget);
    expect(find.text(S.subscriptionPlansColumnPrice), findsOneWidget);
    expect(find.text(S.subscriptionPlansColumnDuration), findsOneWidget);
    expect(find.text(S.subscriptionPlansColumnSubscribers), findsOneWidget);
  });

  testWidgets('the search hides the plans that do not match', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      plans: [for (var index = 1; index <= 4; index++) _plan(index)],
      search: 'PLAN_2',
    );

    expect(_label('Plan 2'), findsOneWidget);
    expect(_label('Plan 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status filter keeps only the paused plans', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      plans: [_plan(1), _plan(2), _plan(3, isActive: false)],
    );

    await tester.tap(find.byTooltip(S.subscriptionPlansFilter));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        PopupMenuItem<SubscriptionPlanFilter>,
        S.subscriptionPlansFilterPaused,
      ),
    );
    await tester.pumpAndSettle();

    expect(_label('Plan 3'), findsOneWidget);
    expect(_label('Plan 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty page offers to add the first plan', (tester) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, plans: const []);

    expect(find.text(S.noSubscriptionPlans), findsOneWidget);
    expect(find.text(S.subscriptionPlanAddAction), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a search with no result offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, plans: [_plan(1)], search: 'missing');

    expect(find.text(S.subscriptionPlansNoMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      plans: [for (var index = 1; index <= 3; index++) _plan(index)],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionPlans), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1280, 900);
    await _pumpPage(
      tester,
      plans: [for (var index = 1; index <= 3; index++) _plan(index)],
      dark: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionPlansColumnPlan), findsOneWidget);
  });
}
