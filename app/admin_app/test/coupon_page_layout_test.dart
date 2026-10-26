import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/presentation/models/coupon_filter.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_directory.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

const _metrics = AdminCouponMetrics(
  active: 3,
  expiringSoon: 1,
  total: 7,
  redemptions: 42,
  uniqueCustomers: 30,
  discountGiven: 1250.5,
);

AdminCoupon _coupon(
  int index, {
  bool isActive = true,
  int? usageLimit,
  int redemptions = 0,
  AdminCouponScope scope = AdminCouponScope.all,
}) {
  final now = DateTime.now();
  return AdminCoupon(
    id: 'c$index',
    code: 'CODE-$index',
    titleAr: 'كوبون $index',
    titleEn: 'Coupon $index',
    discountValue: 10.0 * index,
    scope: scope,
    usageLimit: usageLimit,
    redemptionsCount: redemptions,
    isActive: isActive,
    endsAt: isActive ? now.add(const Duration(days: 30)) : null,
  );
}

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  List<AdminCoupon> coupons = const <AdminCoupon>[],
  AdminCouponMetrics metrics = _metrics,
  String search = '',
  bool canManage = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  ValueChanged<AdminCoupon>? onOpen,
  ValueChanged<AdminCoupon>? onCopy,
  ValueChanged<AdminCoupon>? onToggle,
  ValueChanged<AdminCoupon>? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: CouponPageBody(
          metrics: metrics,
          canManage: canManage,
          onAdd: () {},
          directory: CouponDirectory(
            coupons: coupons,
            search: search,
            onSearchChanged: (_) {},
            canManage: canManage,
            onAdd: () {},
            onOpen: onOpen ?? (_) {},
            onCopy: onCopy ?? (_) {},
            onToggle: onToggle ?? (_) {},
            onDelete: onDelete ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openFilter(
  WidgetTester tester,
  String label,
  String option,
) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(PopupMenuItem<AdminCouponFilter>, option),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the wide page shows the metrics and the coupon table', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(tester, coupons: [_coupon(1), _coupon(2)]);

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminPageFrame), findsOneWidget);
    expect(find.text(S.coupons), findsOneWidget);
    expect(find.text(S.couponsNew), findsOneWidget);
    expect(find.text(S.couponsMetricActive), findsOneWidget);
    expect(find.text(S.couponsMetricExpiring), findsOneWidget);
    expect(find.text(S.couponsMetricRedemptions), findsOneWidget);
    expect(find.text(S.couponsMetricDiscountGiven), findsOneWidget);
    expect(find.text(S.couponsTableCoupon), findsOneWidget);
    expect(find.text(S.couponsTableDiscount), findsOneWidget);
    expect(find.text(S.couponsTableScope), findsOneWidget);
    expect(find.text(S.couponsTableUsage), findsOneWidget);
    expect(find.text(S.couponsTableGiven), findsOneWidget);
    expect(find.text(S.couponsTableWindow), findsOneWidget);
    expect(find.text(S.couponsTableStatus), findsOneWidget);
    expect(find.byKey(const Key('coupon-row-c1')), findsOneWidget);
    expect(find.byKey(const Key('coupon-card-c1')), findsNothing);
    expect(
      find.text(localizeDigits(S.couponsFilterOption(S.couponsFilterAll, 2))),
      findsOneWidget,
    );
    expect(find.text('Coupon 1'), findsOneWidget);
  });

  testWidgets('the narrow page switches to coupon cards', (tester) async {
    _setViewport(tester, 420, 900);
    await _pumpPage(tester, coupons: [_coupon(1), _coupon(2)]);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('coupon-card-c1')), findsOneWidget);
    expect(find.byKey(const Key('coupon-card-c2')), findsOneWidget);
    expect(find.byKey(const Key('coupon-row-c1')), findsNothing);
    expect(find.text(S.couponsTableCoupon), findsNothing);
    expect(find.text('Coupon 1'), findsOneWidget);
  });

  testWidgets('an empty directory offers to create the first coupon', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, metrics: AdminCouponMetrics.empty);

    expect(tester.takeException(), isNull);
    expect(find.text(S.couponsEmpty), findsOneWidget);
    expect(find.text(S.couponsEmptyHint), findsOneWidget);
    expect(find.text(S.couponsNew), findsNWidgets(2));
  });

  testWidgets('a search without a match offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, coupons: [_coupon(1)], search: 'missing');

    expect(tester.takeException(), isNull);
    expect(find.text(S.couponsNoMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);
    expect(find.text('Coupon 1'), findsNothing);
  });

  testWidgets('the paused filter hides the running coupons', (tester) async {
    _setViewport(tester, 1500);
    await _pumpPage(tester, coupons: [_coupon(1), _coupon(2, isActive: false)]);

    await _openFilter(
      tester,
      S.couponsFilter,
      localizeDigits(S.couponsFilterOption(S.couponsStatusPaused, 1)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Coupon 2'), findsOneWidget);
    expect(find.text('Coupon 1'), findsNothing);
  });

  testWidgets('the directory paginates after six coupons', (tester) async {
    _setViewport(tester, 1600);
    await _pumpPage(
      tester,
      coupons: [for (var index = 1; index <= 7; index++) _coupon(index)],
      metrics: AdminCouponMetrics.empty,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('coupon-row-c7')), findsNothing);
    expect(
      find.text(localizeDigits(S.couponsRowsLabel(1, 6, 7))),
      findsOneWidget,
    );

    await tester.tap(find.text(localizeDigits('2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coupon-row-c7')), findsOneWidget);
    expect(find.byKey(const Key('coupon-row-c1')), findsNothing);
    expect(
      find.text(localizeDigits(S.couponsRowsLabel(7, 7, 7))),
      findsOneWidget,
    );
  });

  testWidgets('a read-only manager sees the hint and no actions', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(tester, coupons: [_coupon(1)], canManage: false);

    expect(tester.takeException(), isNull);
    expect(find.text(S.couponsReadOnly), findsOneWidget);
    expect(find.text(S.couponsNew), findsNothing);
    expect(find.byTooltip(S.couponsMenuTooltip), findsNothing);
    expect(find.text('Coupon 1'), findsOneWidget);
  });

  testWidgets('the coupon code can be copied from the table', (tester) async {
    _setViewport(tester, 1500);
    AdminCoupon? copied;
    await _pumpPage(
      tester,
      coupons: [_coupon(1)],
      onCopy: (coupon) => copied = coupon,
    );

    await tester.tap(find.byKey(const Key('coupon-copy-c1')));
    await tester.pump();

    expect(copied?.id, 'c1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      coupons: [_coupon(1), _coupon(2)],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.coupons), findsOneWidget);
    expect(find.text(S.couponsMetricActive), findsOneWidget);
    expect(find.text('كوبون 1'), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, coupons: [_coupon(1), _coupon(2)], dark: true);

    expect(tester.takeException(), isNull);
    expect(find.text(S.couponsTableStatus), findsOneWidget);
    expect(find.byKey(const Key('coupon-row-c2')), findsOneWidget);
  });
}
