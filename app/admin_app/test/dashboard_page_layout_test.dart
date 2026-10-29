import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/core/navigation/admin_navigator.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_channel_slice.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_sales_point.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';
import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_cubit.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';
import 'package:admin_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_channels_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_growth_banner.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_metrics_cards.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_page_body.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_recent_orders_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_sales_overview_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_setup_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_dialog.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_top_products_panel.dart';
import 'package:admin_app/shared/widgets/admin_donut_chart.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_panel_row.dart';
import 'package:admin_app/shared/widgets/admin_progress_ring.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart.dart';

/// لوحة كاملة الأرقام، رقميةٌ مقصودة حتى تُقرأ كل بطاقة من اسمها لا من موضعها.
///
/// المقامات أرقام متناسبة على قصدها: ٩٠٠ من ١٢٠٠ تُعطي «٧٥٪» في حلقة الهدف،
/// و١٥٠ من ٢٠٠ تُعطي «٧٥٪» في شريحة الاستلام. ولو خرجت البطاقة عن هذين الرقمين
/// لكان الحساب في العرض لا في القاعدة.
final _metrics = AdminDashboardMetrics(
  todayOrders: 8,
  todayRevenue: 211.71,
  yesterdayOrders: 5,
  yesterdayRevenue: 140,
  averageOrderValue: 26.46,
  yesterdayAverageOrderValue: 28,
  activeOrders: 4,
  totalOrders: 12,
  weekOrders: 21,
  weekRevenue: 640,
  prevWeekOrders: 18,
  prevWeekRevenue: 500,
  monthOrders: 30,
  monthRevenue: 900,
  prevMonthOrders: 20,
  prevMonthRevenue: 500,
  monthlyRevenueTarget: 1200,
  totalCustomers: 45,
  customersBeforeMonth: 39,
  salesSeries: <AdminDashboardSalesPoint>[
    AdminDashboardSalesPoint(
      date: DateTime(2026, 10, 1),
      revenue: 120,
      orders: 2,
    ),
    AdminDashboardSalesPoint(
      date: DateTime(2026, 10, 2),
      revenue: 240,
      orders: 3,
    ),
  ],
  channels: <AdminDashboardChannelSlice>[
    AdminDashboardChannelSlice(channel: 'pickup', orders: 3, revenue: 150),
    AdminDashboardChannelSlice(channel: 'dine_in', orders: 1, revenue: 50),
  ],
  topProducts: <AdminDashboardTopProduct>[
    AdminDashboardTopProduct(
      nameAr: 'إسبريسو',
      nameEn: 'Espresso',
      quantity: 3,
      revenue: 27,
    ),
    AdminDashboardTopProduct(
      nameAr: 'آيس تي فواكه',
      nameEn: 'Iced Fruit Tea',
      quantity: 2,
      revenue: 36,
    ),
  ],
  recentOrders: <AdminDashboardRecentOrder>[
    AdminDashboardRecentOrder(
      id: 'r1',
      orderNumber: 'ORD-71',
      status: 'completed',
      fulfillmentType: 'delivery',
      grandTotal: 55,
      itemsCount: 2,
      placedAt: DateTime(2026, 10, 2, 18),
      customerName: 'Sara',
    ),
    AdminDashboardRecentOrder(
      id: 'r2',
      orderNumber: 'ORD-72',
      status: 'cancelled',
      fulfillmentType: 'pickup',
      grandTotal: 19,
      itemsCount: 1,
      placedAt: DateTime(2026, 10, 1, 9),
    ),
  ],
  setupSteps: <DashboardSetupStep>[
    DashboardSetupStep(key: 'first_product', done: true),
    DashboardSetupStep(key: 'branch_image', done: false),
    DashboardSetupStep(key: 'revenue_target', done: true),
    DashboardSetupStep(key: 'first_order', done: true),
  ],
);

void _setViewport(WidgetTester tester, double width, [double height = 1100]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// يُنهي ظهور البطاقات المتدرّج قبل القراءة أو الضغط.
Future<void> _reveal(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// رقم داخل بطاقة واحدة: اللوحة كلها تعرض أرقامًا قد تتكرر بين بطاقتين،
/// فيُقرأ الرقم من موضعه لا من عدد مرات طباعته في الشاشة كلها.
Finder _inside(Type card, Finder matching) =>
    find.descendant(of: find.byType(card), matching: matching);

/// جملة تُطبع داخل `Text.rich` فلا يراها البحث عن `Text` وحده؛ النسبة فيها
/// قطعةٌ داخل الكلام، والاختبار يقرأ الكلام كلّه من موضع البطاقة.
Finder _sentence(Type card, String text) => find.descendant(
  of: find.byType(card),
  matching: find.textContaining(text, findRichText: true),
);

Future<void> _pumpBody(
  WidgetTester tester, {
  AdminDashboardMetrics? metrics,
  String search = '',
  int rangeDays = 30,
  bool canManageTarget = true,
  bool canAddProduct = true,
  String? errorMessage,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  bool inShell = true,
  VoidCallback? onRefresh,
  ValueChanged<int>? onRangeChanged,
  ValueChanged<String>? onNavigate,
  VoidCallback? onEditTarget,
}) async {
  final body = DashboardPageBody(
    state: AdminDashboardState(
      status: AdminDashboardStatus.ready,
      metrics: metrics ?? _metrics,
      searchQuery: search,
      salesRangeDays: rangeDays,
      errorMessage: errorMessage,
    ),
    staffName: 'Ahmed',
    canManageTarget: canManageTarget,
    canAddProduct: canAddProduct,
    onRefresh: onRefresh ?? () {},
    onRangeChanged: onRangeChanged ?? (_) {},
    onEditTarget: onEditTarget ?? () {},
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: inShell
            ? AdminNavigator(onSelect: onNavigate ?? (_) {}, child: body)
            : body,
      ),
    ),
  );
  await _reveal(tester);
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('dashboard page body', () {
    testWidgets('every panel the database fills is on the board', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminPageFrame), findsOneWidget);
      // الترحيب يعرف ساعتها: «صباح الخير» تُقرأ مساءً كذبًا صغيرًا، فالقارئ
      // هنا يثبت الاسم لا وقت الشاشة.
      expect(find.textContaining('Ahmed'), findsOneWidget);

      for (final title in <String>[
        S.dashboardTargetCardTitle,
        S.dashboardSalesOverviewTitle,
        S.dashboardSetupTitle,
        S.recentOrders,
        S.dashboardChannelsTitle,
        S.dashboardBestSellersTitle,
      ]) {
        expect(find.text(title), findsOneWidget, reason: '$title missing');
      }

      expect(find.byType(AdminTrendChart), findsOneWidget);
      expect(find.byType(AdminDonutChart), findsOneWidget);
      expect(find.byType(AdminProgressRing), findsOneWidget);
      expect(find.byType(AdminSegmentedControl), findsOneWidget);
      // ثلاثة صفوف: كل رقم يُطبع مرّة في اللوحة، وعشر بطاقات في عمود تُقرأ
      // قائمةً لا لوحة.
      expect(find.byType(AdminPanelRow), findsNWidgets(3));
    });

    testWidgets('the four tiles read the month numbers the database returned', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      expect(
        find.widgetWithText(AdminMetricCard, S.dashboardAverageOrderValue),
        findsOneWidget,
      );
      expect(
        _inside(DashboardMetricsCards, find.text('26.46')),
        findsOneWidget,
      );
      // أساس النسبة مطبوع تحتها: شارةٌ وحدها تترك للأدمن أن يخمّن أمس.
      expect(
        _inside(
          DashboardMetricsCards,
          find.text(S.dashboardYesterday('28.00')),
        ),
        findsOneWidget,
      );
      // والإشارة مطبوعة مع النسبة: قارئ الشاشة يلفظ النصّ وحده فلا يسمع من السهم.
      expect(
        _inside(DashboardMetricsCards, find.text('−5.5%')),
        findsOneWidget,
      );

      // العملاء بلاطة تُقارَن بما كان قبل الشهر، لا بما كان فيه.
      expect(
        find.widgetWithText(AdminMetricCard, S.customersLabel),
        findsOneWidget,
      );
      expect(
        _inside(DashboardMetricsCards, find.text(localizeDigits('45'))),
        findsOneWidget,
      );
      expect(
        _inside(
          DashboardMetricsCards,
          find.text(S.dashboardBeforeThisMonth(localizeDigits('39'))),
        ),
        findsOneWidget,
      );

      // ٣٠ من ٢٠ طلبًا: +٥٠٪، و٩٠٠ من ٥٠٠ مالًا: +٨٠٪.
      expect(
        _inside(DashboardMetricsCards, find.text(localizeDigits('30'))),
        findsOneWidget,
      );
      expect(
        _inside(
          DashboardMetricsCards,
          find.text(S.dashboardLastMonth(localizeDigits('20'))),
        ),
        findsOneWidget,
      );
      expect(
        _inside(
          DashboardMetricsCards,
          find.text(S.dashboardLastMonth('500.00')),
        ),
        findsOneWidget,
      );
      expect(_inside(DashboardMetricsCards, find.text('+50%')), findsOneWidget);
      expect(_inside(DashboardMetricsCards, find.text('+80%')), findsOneWidget);
    });

    testWidgets('the customers tile works for a role that cannot read them', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(
        tester,
        metrics: const AdminDashboardMetrics(
          activeOrders: 6,
          totalOrders: 9,
          monthOrders: 3,
          monthRevenue: 60,
        ),
      );

      // صفرٌ في خانة حُجبت عن هذا الحساب كذب، وشرطةٌ تسأل بلا جواب: البلاطة
      // تنتقل إلى العمل المفتوح أمامه وتُسمّيه باسمه.
      expect(find.text(S.customersLabel), findsNothing);
      expect(
        find.widgetWithText(AdminMetricCard, S.activeOrders),
        findsOneWidget,
      );
      expect(
        _inside(DashboardMetricsCards, find.text(localizeDigits('6'))),
        findsOneWidget,
      );
      expect(find.text(S.dashboardOpenWorkCaption), findsOneWidget);
      expect(find.text(S.dashboardBeforeThisMonth('39')), findsNothing);
    });

    testWidgets('the growth banner needs a real rise to speak', (tester) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      expect(find.text(S.dashboardGrowthHeadline), findsOneWidget);
      // النسبة من رقمي الشهر (٩٠٠ مقابل ٥٠٠) داخل جملة واحدة، لا شارة طائرة.
      expect(
        _sentence(DashboardGrowthBanner, 'Sales are up +80%'),
        findsOneWidget,
      );

      await _pumpBody(
        tester,
        metrics: const AdminDashboardMetrics(
          totalOrders: 4,
          monthOrders: 2,
          monthRevenue: 400,
          prevMonthRevenue: 500,
        ),
      );
      // تهنئة في يومٍ سيئ أسوأ من غيابها: مع الانخفاض لا شريط أصلًا.
      expect(find.text(S.dashboardGrowthHeadline), findsNothing);

      await _pumpBody(
        tester,
        metrics: const AdminDashboardMetrics(
          totalOrders: 1,
          monthOrders: 1,
          monthRevenue: 120,
        ),
      );
      // وبلا أساس تُترك المقارنة كلها: نسبةٌ تُحسب من صفر كذبة.
      expect(find.text(S.dashboardGrowthHeadline), findsNothing);
      expect(
        find.textContaining(S.dashboardVsPreviousPeriod, findRichText: true),
        findsNothing,
      );
    });

    testWidgets('the banner follows the window the admin selected', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester, rangeDays: 7);

      // ٦٤٠ مقابل ٥٠٠: الأسبوع نفسه، لا الشهر الذي يقرأه الشريط في المدى الآخر.
      expect(
        _sentence(DashboardGrowthBanner, 'Sales are up +28%'),
        findsOneWidget,
      );
      expect(_inside(DashboardGrowthBanner, find.text('+80%')), findsNothing);
    });

    testWidgets('the target card rings the month against its target', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      // ٩٠٠ من ١٢٠٠: النسبة في الحلقة، ومقامها مطبوع تحتها في البطاقة نفسها.
      expect(_inside(DashboardTargetCard, find.text('75%')), findsOneWidget);
      expect(
        _inside(DashboardTargetCard, find.text('1,200.00')),
        findsOneWidget,
      );
      expect(_inside(DashboardTargetCard, find.text('900.00')), findsOneWidget);
      expect(
        _inside(DashboardTargetCard, find.text(S.dashboardCurrentSales)),
        findsOneWidget,
      );
      // ما بقي هو الذي يحرّك الأدمن، لا النسبة وحدها.
      expect(
        _inside(DashboardTargetCard, find.text(S.dashboardRemainingToTarget)),
        findsOneWidget,
      );
      expect(_inside(DashboardTargetCard, find.text('300.00')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-target-edit')), findsOneWidget);

      await _pumpBody(
        tester,
        metrics: const AdminDashboardMetrics(
          totalOrders: 3,
          monthOrders: 3,
          monthRevenue: 1300,
          monthlyRevenueTarget: 1200,
        ),
      );
      // المتجاوز يُقال نصًّا، والحلقة تُقصّ عند تمامها فلا تخرج من البطاقة.
      expect(_inside(DashboardTargetCard, find.text('100%')), findsOneWidget);
      expect(
        _inside(DashboardTargetCard, find.text(S.dashboardTargetReached)),
        findsOneWidget,
      );
      // الفرجة تُستبدل بالخبر: لا «تبقّى −١٠٠» يُطبع أمام عين الأدمن.
      expect(find.text('-100.00'), findsNothing);
      expect(find.textContaining(S.dashboardRemainingToTarget), findsNothing);
    });

    testWidgets('a month without a target says so instead of drawing a ring', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(
        tester,
        metrics: const AdminDashboardMetrics(
          totalOrders: 3,
          monthRevenue: 60,
          monthOrders: 3,
        ),
      );

      expect(find.text(S.dashboardTargetEmpty), findsOneWidget);
      expect(find.text(S.dashboardTargetEmptyHint), findsOneWidget);
      expect(find.byType(AdminProgressRing), findsNothing);
      expect(find.text(S.dashboardTargetSet), findsOneWidget);
    });

    testWidgets('the editor opens from the card that carries the amount', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      var opened = 0;
      await _pumpBody(tester, onEditTarget: () => opened++);

      await tester.tap(find.byKey(const Key('dashboard-target-edit')));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('a manager of one branch is not shown the company target', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester, canManageTarget: false);

      // رقمٌ عام أمام فرع واحد يُقرأ خطأً على أنه هدفُه: البطاقة لا تُبنى أصلًا.
      expect(find.byType(DashboardTargetCard), findsNothing);
      expect(find.text(S.dashboardTargetCardTitle), findsNothing);
      expect(find.text(S.dashboardSalesOverviewTitle), findsOneWidget);
      // والحلقة وحدها تقيس الهدف؛ شريحة الاستلام تبقى لأن مالها لها مقام آخر.
      expect(find.byType(AdminProgressRing), findsNothing);
    });

    testWidgets('the card that lists the steps counts the steps it lists', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      // ٣ من ٤ مُنجَز، والسطر المنتظر وحده يحمل رقم موضعه.
      expect(_inside(DashboardSetupCard, find.text('3/4')), findsOneWidget);
      expect(
        _inside(DashboardSetupCard, find.text(S.dashboardSetupDone)),
        findsNWidgets(3),
      );
      expect(find.text(S.dashboardSetupBranchImage), findsOneWidget);
      expect(_inside(DashboardSetupCard, find.text('2')), findsOneWidget);
    });

    testWidgets('a step the board cannot name is neither shown nor counted', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(
        tester,
        metrics: AdminDashboardMetrics(
          totalOrders: 1,
          monthRevenue: 40,
          monthOrders: 1,
          setupSteps: const [
            DashboardSetupStep(key: 'first_product', done: true),
            DashboardSetupStep(key: 'shipping_zone', done: false),
          ],
        ),
      );

      // «١/٢» فوق سطر واحد يُقرأ كذبًا، والمفتاح الخام شيفرة أمام الأدمن.
      expect(_inside(DashboardSetupCard, find.text('1/1')), findsOneWidget);
      expect(find.text(S.dashboardSetupFirstProduct), findsOneWidget);
      expect(find.text('shipping_zone'), findsNothing);
    });

    testWidgets('the setup card leaves the row when this reader has no steps', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester, metrics: AdminDashboardMetrics.empty);

      expect(find.text(S.dashboardSetupTitle), findsNothing);
      // بلا لوحة جانبية تأخذ اللوحة العريضة العرض كله، فلا نصف صفحة فارغ.
      expect(find.text(S.noOrdersYet), findsNWidgets(2));
    });

    testWidgets('the sales card totals its own window and labels its axis', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      // النافذة يومان: ١٢٠+٢٤٠ مالًا، والمحور يُقسَم على قمة النافذة نفسها لا
      // على رقم مريح للعين.
      expect(
        _inside(
          DashboardSalesOverviewCard,
          find.text(localizeDigits('360.00')),
        ),
        findsOneWidget,
      );
      for (final label in ['240', '180', '120', '60', '0']) {
        expect(
          _inside(DashboardSalesOverviewCard, find.text(label)),
          findsOneWidget,
          reason: 'axis label $label missing',
        );
      }
      expect(
        _sentence(
          DashboardSalesOverviewCard,
          '+80% ${S.dashboardVsPreviousPeriod}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the trend switch asks for the other window', (tester) async {
      _setViewport(tester, 1500);
      final asked = <int>[];
      await _pumpBody(tester, onRangeChanged: asked.add);

      await tester.tap(find.text(localizeDigits(S.dashboardRangeWeek)));
      await tester.pumpAndSettle();

      expect(asked, <int>[7]);
    });

    testWidgets('the orders table prints the columns the orders page uses', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      for (final header in [
        S.orderNumber,
        S.customer,
        S.date,
        S.total,
        S.status,
      ]) {
        expect(
          _inside(DashboardRecentOrdersCard, find.text(header)),
          findsOneWidget,
          reason: 'column $header missing',
        );
      }
      expect(find.text('ORD-71'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      // الطلب بلا اسم يبقى بلا اسم، لا «null» ولا عميل مُختَرَع.
      expect(
        _inside(
          DashboardRecentOrdersCard,
          find.text(S.dashboardAnonymousCustomer),
        ),
        findsOneWidget,
      );
      expect(
        _inside(
          DashboardRecentOrdersCard,
          find.text(OrderStatusView.of('completed').label),
        ),
        findsOneWidget,
      );
      expect(
        _inside(DashboardRecentOrdersCard, find.text('55.00')),
        findsOneWidget,
      );
      // شارة العدد عدد الأسطر المعروضة، فالبحث ينقصها والنصّ يبقى.
      expect(
        _inside(DashboardRecentOrdersCard, find.text(localizeDigits('2'))),
        findsOneWidget,
      );
    });

    testWidgets('the channels card shares the window money, not its orders', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      expect(find.text(S.fulfillmentPickup), findsOneWidget);
      expect(find.text(S.fulfillmentDineIn), findsOneWidget);
      // ١٥٠ من ٢٠٠ و٥٠ من ٢٠٠: حصة كل قناة من مال المدى الذي جمعته القاعدة.
      expect(_inside(DashboardChannelsCard, find.text('75%')), findsOneWidget);
      expect(_inside(DashboardChannelsCard, find.text('25%')), findsOneWidget);
      expect(
        _inside(DashboardChannelsCard, find.text('150.00')),
        findsOneWidget,
      );
      // عدد الطلبات يبقى مكتوبًا: النسبة وحدها تُخفي قناةً طلباتها كثيرة.
      expect(
        _inside(DashboardChannelsCard, find.text(localizeDigits('3'))),
        findsOneWidget,
      );
    });

    testWidgets('the best sellers row ranks, names and prices each product', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpBody(tester);

      // الرتبة بخانتين كما في التصميم، والحصّة من مال الأسبوع (٦٤٠).
      expect(
        _inside(DashboardTopProductsPanel, find.text('01')),
        findsOneWidget,
      );
      expect(
        _inside(DashboardTopProductsPanel, find.text('02')),
        findsOneWidget,
      );
      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('Iced Fruit Tea'), findsOneWidget);
      expect(
        _inside(
          DashboardTopProductsPanel,
          find.text(localizeDigits(S.dashboardPiecesSold(3))),
        ),
        findsOneWidget,
      );
      expect(
        _inside(DashboardTopProductsPanel, find.text('27.00')),
        findsOneWidget,
      );
      expect(
        _inside(DashboardTopProductsPanel, find.text('4.2%')),
        findsOneWidget,
      );
      // بلا شارة عدد فوق صفوف تنتهي بعدّهم نفسها.
      expect(
        _inside(DashboardTopProductsPanel, find.text(localizeDigits('2'))),
        findsNothing,
      );
    });

    testWidgets('the links hand the move to the shell and vanish without it', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      final destinations = <String>[];
      await _pumpBody(tester, onNavigate: destinations.add);

      await tester.tap(find.byKey(const Key('admin-section-link-orders')));
      await tester.tap(find.byKey(const Key('admin-section-link-products')));
      await tester.pumpAndSettle();

      expect(destinations, <String>['orders', 'products']);

      await _pumpBody(tester, inShell: false);
      // خارج القشرة لا يد تُستعار، فلا زرّ يعدو إلى قسم لا يفتحه.
      expect(find.text(S.dashboardViewAllOrders), findsNothing);
      expect(find.text(S.dashboardViewAllProducts), findsNothing);

      await _pumpBody(tester);
      expect(find.byKey(const Key('dashboard-add-product')), findsOneWidget);

      // `admin_save_product` يطلب catalog.product.write، فمن لا يملكها لا يرى
      // يدًا تُوهمه أنه يضيف منتجًا.
      await _pumpBody(tester, canAddProduct: false);
      expect(find.byKey(const Key('dashboard-add-product')), findsNothing);
    });

    testWidgets('the Arabic page names the panels and the rows in Arabic', (
      tester,
    ) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      _setViewport(tester, 1500);
      await _pumpBody(tester, direction: TextDirection.rtl);

      expect(tester.takeException(), isNull);
      expect(find.text('خطوات البداية'), findsOneWidget);
      expect(find.text('المنتجات الأكثر مبيعًا'), findsOneWidget);
      expect(find.text('إسبريسو'), findsOneWidget);
      expect(find.text('٣ قطعة مباعة'), findsOneWidget);
      expect(find.text('عميل غير مسجَّل'), findsOneWidget);
      // الأرقام تُقرأ بأرقام اللغة، والمقام مطبوع معها.
      expect(_inside(DashboardMetricsCards, find.text('٣٠')), findsOneWidget);
      expect(_inside(DashboardSetupCard, find.text('٣/٤')), findsOneWidget);
      expect(find.text('٧٥٪'), findsAtLeastNWidgets(1));
      // رقم الطلب معرّف: يبقى كما في شاشة الطلبات وكما يُكتب في البحث، فلا
      // يقلبه التوطين إلى حروف عربية لا يطابقها أحد.
      expect(find.text('ORD-71'), findsOneWidget);
      expect(find.text(localizeDigits('ORD-71')), findsNothing);
    });

    testWidgets('a brand with no orders says so instead of inventing tiles', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      await _pumpBody(tester, metrics: AdminDashboardMetrics.empty);

      expect(tester.takeException(), isNull);
      expect(find.text(S.noOrdersYet), findsNWidgets(2));
      expect(find.text(S.dashboardChannelsEmpty), findsOneWidget);
      expect(find.text(S.dashboardSalesEmpty), findsOneWidget);
      expect(find.text(S.dashboardTargetEmpty), findsOneWidget);
      expect(find.byType(AdminTrendChart), findsNothing);
      expect(find.byType(AdminDonutChart), findsNothing);
      expect(find.byType(AdminEmptyState), findsNWidgets(4));
    });

    testWidgets('a search narrows the rows and says when it left nothing', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      await _pumpBody(tester, search: 'espresso');

      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('Iced Fruit Tea'), findsNothing);
      // لا طلب اسمه espresso، فتفرغ بطاقته برسالته هي لا برسالة «لا طلب بعد».
      expect(find.text(S.dashboardNothingMatches), findsOneWidget);
      expect(find.text(S.noOrdersYet), findsNothing);

      await _pumpBody(tester, search: 'nothing here');
      expect(find.text(S.dashboardNothingMatches), findsNWidgets(2));
    });

    testWidgets('searching a state keeps the rows that carry it', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      await _pumpBody(tester, search: 'completed');

      expect(find.text('ORD-71'), findsOneWidget);
      expect(find.text('ORD-72'), findsNothing);
      expect(
        _inside(DashboardRecentOrdersCard, find.text(localizeDigits('1'))),
        findsOneWidget,
      );

      await _pumpBody(tester, search: 'sara');
      expect(find.text('ORD-71'), findsOneWidget);
      expect(find.text('ORD-72'), findsNothing);
    });

    testWidgets('the refresh button asks the page to read again', (
      tester,
    ) async {
      var calls = 0;
      _setViewport(tester, 1280);
      await _pumpBody(tester, onRefresh: () => calls++);

      await tester.tap(find.byKey(const Key('dashboard-refresh')));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('a failed reload keeps the numbers and says what broke', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      await _pumpBody(tester, errorMessage: 'boom');

      expect(find.text('boom'), findsOneWidget);
      expect(find.text(S.dashboardNewOrders), findsOneWidget);
    });

    testWidgets('the narrow dark dashboard stacks and fits', (tester) async {
      _setViewport(tester, 420, 900);
      await _pumpBody(tester, dark: true);

      expect(tester.takeException(), isNull);
      expect(find.text(S.dashboardTotalSales), findsOneWidget);
      expect(find.text(S.dashboardBestSellersTitle), findsOneWidget);
      expect(find.byType(AdminEmptyState), findsNothing);
    });
  });

  group('the route', () {
    testWidgets('opening the dashboard reads the metrics once', (tester) async {
      _setViewport(tester, 1280);
      final repository = _FakeDashboardRepository();
      final cubit = AdminDashboardCubit(repository: repository);
      await cubit.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: AdminNavigator(
            onSelect: (_) {},
            child: DashboardPage(
              searchController: AdminSearchController(),
              staffName: 'Ahmed',
              canManageTarget: true,
              canAddProduct: true,
              cubit: cubit,
            ),
          ),
        ),
      );
      await _reveal(tester);

      expect(tester.takeException(), isNull);
      expect(repository.loads, 1);
      expect(find.text(S.dashboardNewOrders), findsOneWidget);
      expect(find.textContaining('Ahmed'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('the shell search field filters the board through the cubit', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      final cubit = AdminDashboardCubit(repository: _FakeDashboardRepository());
      await cubit.load();
      final search = AdminSearchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: AdminNavigator(
            onSelect: (_) {},
            child: DashboardPage(
              searchController: search,
              staffName: 'Ahmed',
              canManageTarget: true,
              canAddProduct: true,
              cubit: cubit,
            ),
          ),
        ),
      );
      await _reveal(tester);

      search.update('espresso');
      await _reveal(tester);

      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('Iced Fruit Tea'), findsNothing);
      await cubit.close();
    });
  });

  group('the target editor', () {
    // سقف ٢٠٣ رقمٌ ترفضه القاعدة لا صفرٌ تكتبه الواجهة، والأرقام العربية تُقرأ
    // لأنها الطريقة التي تطبع بها اللوحة كل مبلغ.
    testWidgets('reads an amount typed in Arabic numerals', (tester) async {
      double? written;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: Scaffold(
            body: DashboardTargetDialog(
              current: null,
              onSubmit: (value) async {
                written = value;
                return null;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '١٬٥٠٠٫٢٥');
      await tester.tap(find.byKey(const Key('dashboard-target-save')));
      await tester.pumpAndSettle();

      expect(written, 1500.25);
    });

    testWidgets('refuses an amount over the database ceiling', (tester) async {
      double? written;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: Scaffold(
            body: DashboardTargetDialog(
              current: null,
              onSubmit: (value) async {
                written = value;
                return null;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '100000001');
      await tester.tap(find.byKey(const Key('dashboard-target-save')));
      await tester.pumpAndSettle();

      expect(find.text(S.dashboardTargetTooLarge), findsOneWidget);
      expect(written, isNull);
    });
  });
}

/// القراءة وكتابة الهدف مزروعتان: الصفحة لا تسأل Supabase في اختبار واجهة.
class _FakeDashboardRepository implements DashboardRepository {
  int loads = 0;

  @override
  Future<AdminDashboardMetrics> loadMetrics() async {
    loads++;
    return _metrics;
  }

  @override
  Future<void> saveRevenueTarget(double? value) async {}
}
