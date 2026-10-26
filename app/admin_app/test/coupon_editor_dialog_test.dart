import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon_targets.dart';
import 'package:admin_app/features/coupons/data/repositories/admin_coupon_repository.dart';
import 'package:admin_app/features/coupons/presentation/manager/admin_coupon_cubit.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_editor_dialog.dart';

class _FakeCouponCubit extends AdminCouponCubit {
  _FakeCouponCubit({this.outcome = CouponSaveOutcome.saved, this.targets});

  final CouponSaveOutcome outcome;
  final AdminCouponTargets? targets;
  AdminCouponDraft? saved;
  int targetLoads = 0;

  @override
  Future<CouponSaveOutcome> saveCoupon(AdminCouponDraft draft) async {
    saved = draft;
    return outcome;
  }

  @override
  Future<void> loadTargets() async {
    targetLoads++;
    final catalogue = targets;
    if (catalogue != null) emit(state.copyWith(targets: catalogue));
  }
}

const _targets = AdminCouponTargets(
  categories: [
    AdminCouponCategoryTarget(
      id: 'cat-1',
      nameAr: 'قهوة',
      nameEn: 'Coffee',
      productsCount: 4,
    ),
    AdminCouponCategoryTarget(
      id: 'cat-2',
      nameAr: 'حلويات',
      nameEn: 'Desserts',
      productsCount: 2,
    ),
  ],
  products: [
    AdminCouponProductTarget(
      id: 'prod-1',
      nameAr: 'لاتيه',
      nameEn: 'Latte',
      sku: 'LAT-1',
      categoryNameEn: 'Coffee',
    ),
    AdminCouponProductTarget(
      id: 'prod-2',
      nameAr: 'كرواسون',
      nameEn: 'Croissant',
      sku: 'CRO-1',
      categoryNameEn: 'Bakery',
      isArchived: true,
    ),
  ],
);

AdminCoupon _existing() => AdminCoupon(
  id: 'c1',
  code: 'SAVE20',
  titleAr: 'عرض الأسبوع',
  titleEn: 'Weekend treat',
  descriptionAr: 'خصم على كل القائمة',
  descriptionEn: 'A discount across the menu',
  discountValue: 15,
  maxDiscount: 50,
  minOrderAmount: 100,
  usageLimit: 100,
  perUserLimit: 2,
  startsAt: DateTime(2026, 5, 1),
  endsAt: DateTime(2026, 6, 1, 23, 59, 59),
  isActive: true,
);

void _setViewport(
  WidgetTester tester, [
  double width = 1200,
  double height = 1000,
]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openDialog(
  WidgetTester tester,
  _FakeCouponCubit cubit, {
  AdminCoupon? coupon,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showCouponEditorDialog(
                context: context,
                cubit: cubit,
                coupon: coupon,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  final field = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextFormField),
  );
  return tester.widget<TextFormField>(field).controller?.text ?? '';
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(Key(key));
  await _reveal(tester, finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('coupon-editor-save')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the current coupon fills the form and saves the new values', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit();
    await _openDialog(tester, cubit, coupon: _existing());

    expect(find.text(S.couponsEditorEdit), findsOneWidget);
    expect(_fieldText(tester, 'coupon-editor-code'), 'SAVE20');
    expect(_fieldText(tester, 'coupon-editor-title-ar'), 'عرض الأسبوع');
    expect(_fieldText(tester, 'coupon-editor-title-en'), 'Weekend treat');
    expect(_fieldText(tester, 'coupon-editor-value'), '15');
    expect(_fieldText(tester, 'coupon-editor-max-discount'), '50');
    expect(_fieldText(tester, 'coupon-editor-min-order'), '100');
    expect(_fieldText(tester, 'coupon-editor-usage-limit'), '100');
    expect(_fieldText(tester, 'coupon-editor-per-customer'), '2');

    await _enter(tester, 'coupon-editor-code', 'brew30');
    await _enter(tester, 'coupon-editor-value', '25');
    expect(_fieldText(tester, 'coupon-editor-code'), 'BREW30');

    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, 'c1');
    expect(draft.code, 'BREW30');
    expect(draft.discountType, AdminCouponDiscountType.percentage);
    expect(draft.discountValue, 25);
    expect(draft.maxDiscount, 50);
    expect(draft.minOrderAmount, 100);
    expect(draft.usageLimit, 100);
    expect(draft.perUserLimit, 2);
    expect(draft.startsAt, isNotNull);
    expect(draft.endsAt, isNotNull);
    expect(draft.isActive, isTrue);
    expect(find.byKey(const Key('coupon-editor-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic digits and separators are accepted', (tester) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit();
    await _openDialog(tester, cubit);

    await _enter(tester, 'coupon-editor-code', 'save10');
    await _enter(tester, 'coupon-editor-title-ar', 'عرض خاص');
    await _enter(tester, 'coupon-editor-title-en', 'Special offer');
    await _enter(tester, 'coupon-editor-value', '٢٥');
    await _enter(tester, 'coupon-editor-max-discount', '١٠٠٫٥');
    await _enter(tester, 'coupon-editor-min-order', '٥٠');
    await _enter(tester, 'coupon-editor-usage-limit', '١٠');
    await _enter(tester, 'coupon-editor-per-customer', '٢');

    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.code, 'SAVE10');
    expect(draft.discountValue, 25);
    expect(draft.maxDiscount, 100.5);
    expect(draft.minOrderAmount, 50);
    expect(draft.usageLimit, 10);
    expect(draft.perUserLimit, 2);
    expect(draft.scope, AdminCouponScope.all);
    expect(draft.descriptionAr, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid values are refused with localized errors', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit();
    await _openDialog(tester, cubit);

    await _tapSave(tester);
    expect(find.text(S.couponsErrorCode), findsOneWidget);
    expect(find.text(S.couponsErrorTitleAr), findsOneWidget);
    expect(find.text(S.couponsErrorTitleEn), findsOneWidget);
    expect(cubit.saved, isNull);

    await _enter(tester, 'coupon-editor-code', 'AB');
    await _enter(tester, 'coupon-editor-title-ar', 'عرض');
    await _enter(tester, 'coupon-editor-title-en', 'Offer');
    await _enter(tester, 'coupon-editor-value', '0');
    await _tapSave(tester);
    expect(find.text(S.couponsErrorDiscount), findsOneWidget);
    expect(cubit.saved, isNull);

    await _enter(tester, 'coupon-editor-value', '150');
    await _tapSave(tester);
    expect(find.text(S.couponsErrorPercentage), findsOneWidget);
    expect(cubit.saved, isNull);

    await _enter(tester, 'coupon-editor-value', '10');
    await _enter(tester, 'coupon-editor-code', 'ABC');
    await _enter(tester, 'coupon-editor-usage-limit', '3');
    await _enter(tester, 'coupon-editor-per-customer', '5');
    await _tapSave(tester);
    expect(find.text(S.couponsErrorPerCustomer), findsOneWidget);
    expect(cubit.saved, isNull);
    expect(find.byKey(const Key('coupon-editor-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a paused coupon sends the defaults', (tester) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit();
    await _openDialog(tester, cubit);

    await _enter(tester, 'coupon-editor-code', 'PAUSED1');
    await _enter(tester, 'coupon-editor-title-ar', 'عرض');
    await _enter(tester, 'coupon-editor-title-en', 'Offer');
    await _tapKey(tester, const Key('coupon-editor-active'));
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, isNull);
    expect(draft.isActive, isFalse);
    expect(draft.scope, AdminCouponScope.all);
    expect(draft.categoryIds, isEmpty);
    expect(draft.productIds, isEmpty);
    expect(draft.discountType, AdminCouponDiscountType.percentage);
    expect(draft.discountValue, 10);
    expect(draft.maxDiscount, isNull);
    expect(draft.minOrderAmount, 0);
    expect(draft.usageLimit, isNull);
    expect(draft.perUserLimit, 1);
    expect(draft.descriptionAr, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fixed amount coupon drops the maximum discount', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit();
    await _openDialog(tester, cubit);

    await _enter(tester, 'coupon-editor-code', 'FIXED10');
    await _enter(tester, 'coupon-editor-title-ar', 'عرض');
    await _enter(tester, 'coupon-editor-title-en', 'Offer');
    await _tapText(tester, S.couponsDiscountTypeFixed);
    expect(find.byKey(const Key('coupon-editor-max-discount')), findsNothing);

    await _enter(tester, 'coupon-editor-value', '20');
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.discountType, AdminCouponDiscountType.fixedAmount);
    expect(draft.discountValue, 20);
    expect(draft.maxDiscount, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected save keeps the dialog open with the mapped error', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit(outcome: CouponSaveOutcome.duplicateCode);
    await _openDialog(tester, cubit);

    await _enter(tester, 'coupon-editor-code', 'SAVE20');
    await _enter(tester, 'coupon-editor-title-ar', 'عرض');
    await _enter(tester, 'coupon-editor-title-en', 'Offer');
    await _tapSave(tester);

    expect(cubit.saved, isNotNull);
    expect(find.text(S.couponsErrorDuplicate), findsOneWidget);
    expect(find.byKey(const Key('coupon-editor-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a scoped coupon requires a target and keeps the picked ids', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit(targets: _targets);
    await _openDialog(tester, cubit);

    await _enter(tester, 'coupon-editor-code', 'COFFEE10');
    await _enter(tester, 'coupon-editor-title-ar', 'عرض');
    await _enter(tester, 'coupon-editor-title-en', 'Offer');
    await _tapText(tester, S.couponsScopeCategoriesShort);

    expect(find.byKey(const Key('coupon-editor-scope')), findsOneWidget);
    await _tapSave(tester);
    expect(find.text(S.couponsErrorScope), findsOneWidget);
    expect(cubit.saved, isNull);

    await _tapKey(tester, const Key('coupon-editor-scope'));
    expect(cubit.targetLoads, 1);
    expect(find.byKey(const Key('coupon-scope-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('coupon-scope-option-cat-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('coupon-scope-apply')));
    await tester.pumpAndSettle();

    expect(
      find.text(localizeDigits(S.couponsSelectedCount(1))),
      findsOneWidget,
    );
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.scope, AdminCouponScope.category);
    expect(draft.categoryIds, ['cat-1']);
    expect(draft.productIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an end date before the start is refused', (tester) async {
    _setViewport(tester);
    final cubit = _FakeCouponCubit();
    await _openDialog(
      tester,
      cubit,
      coupon: AdminCoupon(
        id: 'c2',
        code: 'WINDOW1',
        titleAr: 'نافذة',
        titleEn: 'Window',
        discountValue: 10,
        startsAt: DateTime(2026, 6, 1),
        endsAt: DateTime(2026, 5, 1, 23, 59, 59),
      ),
    );

    await _tapSave(tester);

    expect(find.text(S.couponsErrorWindow), findsOneWidget);
    expect(cubit.saved, isNull);
    expect(find.byKey(const Key('coupon-editor-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
