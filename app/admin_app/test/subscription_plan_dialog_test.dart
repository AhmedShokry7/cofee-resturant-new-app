import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_cubit.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_state.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_dialog.dart';

class _FakePlanCubit extends AdminSubscriptionPlanCubit {
  _FakePlanCubit({
    this.outcome = SubscriptionPlanSaveOutcome.saved,
    AdminSubscriptionPlanState initialState =
        const AdminSubscriptionPlanState(),
  }) {
    emit(initialState);
  }

  final SubscriptionPlanSaveOutcome outcome;
  AdminSubscriptionPlanDraft? saved;
  int productOptionsLoads = 0;

  @override
  Future<SubscriptionPlanSaveOutcome> savePlan(
    AdminSubscriptionPlanDraft draft,
  ) async {
    saved = draft;
    return outcome;
  }

  @override
  Future<void> loadProductOptions() async {
    productOptionsLoads++;
  }
}

AdminSubscriptionPlan _existingPlan({
  String productScope = 'all',
  List<AdminSubscriptionPlanProduct> products = const [],
}) => AdminSubscriptionPlan(
  id: 'plan-1',
  code: 'GOLD',
  nameAr: 'الذهبية',
  nameEn: 'Gold',
  price: 249,
  currencyCode: 'SAR',
  durationDays: 30,
  cupsPerCycle: 20,
  bonusType: 'fixed',
  bonusValue: 25,
  renewalPolicy: 'auto',
  autoRenewSupported: true,
  productScope: productScope,
  products: products,
  isForSale: false,
);

void _setViewport(
  WidgetTester tester, [
  double width = 1000,
  double height = 900,
]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openDialog(
  WidgetTester tester,
  _FakePlanCubit cubit, {
  AdminSubscriptionPlan? plan,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showSubscriptionPlanDialog(
                context: context,
                cubit: cubit,
                plan: plan,
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

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(FilledButton, S.subscriptionPlanSaveAction),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('plan-name-ar')), 'الفضية');
  await tester.enterText(find.byKey(const Key('plan-name-en')), 'Silver');
  await tester.enterText(find.byKey(const Key('plan-code')), 'silver_2026');
  await tester.enterText(find.byKey(const Key('plan-price')), '149.5');
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('saving an empty form shows the required errors', (tester) async {
    _setViewport(tester);
    final cubit = _FakePlanCubit();
    await _openDialog(tester, cubit);

    await _tapSave(tester);

    expect(find.text(S.subscriptionPlanRequired), findsWidgets);
    expect(cubit.saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new plan is saved with normalised fields', (tester) async {
    _setViewport(tester);
    final cubit = _FakePlanCubit();
    await _openDialog(tester, cubit);

    await _fillRequiredFields(tester);
    await tester.enterText(find.byKey(const Key('plan-currency')), 'sar');
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, isNull);
    expect(draft.code, 'SILVER_2026');
    expect(draft.nameAr, 'الفضية');
    expect(draft.nameEn, 'Silver');
    expect(draft.price, 149.5);
    expect(draft.currencyCode, 'SAR');
    expect(draft.durationDays, 30);
    expect(draft.cupsPerCycle, 10);
    expect(draft.bonusType, 'none');
    expect(draft.bonusValue, 0);
    expect(draft.isActive, isTrue);
    expect(draft.isForSale, isTrue);
    expect(find.text(S.subscriptionPlanSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing plan is sent with its id and figures', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakePlanCubit();
    await _openDialog(tester, cubit, plan: _existingPlan());

    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, 'plan-1');
    expect(draft.code, 'GOLD');
    expect(draft.price, 249);
    expect(draft.cupsPerCycle, 20);
    expect(draft.bonusType, 'fixed');
    expect(draft.bonusValue, 25);
    expect(draft.renewalPolicy, 'auto');
    expect(draft.autoRenewSupported, isTrue);
    expect(draft.productScope, 'all');
    expect(draft.productIds, isEmpty);
    expect(draft.isForSale, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing plan keeps its selected products', (tester) async {
    _setViewport(tester);
    const product = AdminSubscriptionPlanProduct(
      id: 'prod-1',
      nameAr: 'لاتيه',
      nameEn: 'Latte',
      sku: 'LAT-01',
      categoryNameEn: 'Hot coffee',
    );
    final cubit = _FakePlanCubit(
      initialState: const AdminSubscriptionPlanState(productOptions: [product]),
    );
    await _openDialog(
      tester,
      cubit,
      plan: _existingPlan(productScope: 'selected', products: const [product]),
    );

    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.productScope, 'selected');
    expect(draft.productIds, ['prod-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected scope without any product is rejected', (tester) async {
    _setViewport(tester);
    final cubit = _FakePlanCubit();
    await _openDialog(tester, cubit);

    await _fillRequiredFields(tester);
    final scopeChip = find.byKey(const Key('plan-product-scope-selected'));
    await tester.ensureVisible(scopeChip);
    await tester.pumpAndSettle();
    await tester.tap(scopeChip);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(find.text(S.subscriptionPlanProductsRequired), findsOneWidget);
    expect(cubit.saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting the selected scope reloads an empty option list', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakePlanCubit();
    await _openDialog(tester, cubit);

    final scopeChip = find.byKey(const Key('plan-product-scope-selected'));
    await tester.ensureVisible(scopeChip);
    await tester.pumpAndSettle();
    await tester.tap(scopeChip);
    await tester.pumpAndSettle();

    expect(cubit.productOptionsLoads, 1);
    expect(find.text(S.subscriptionPlanProductsEmptyCatalog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking products stores them on the draft', (tester) async {
    _setViewport(tester, 1000, 1000);
    const latte = AdminSubscriptionPlanProduct(
      id: 'p-latte',
      nameAr: 'لاتيه',
      nameEn: 'Latte',
      sku: 'LAT-01',
      categoryNameEn: 'Hot coffee',
    );
    const mocha = AdminSubscriptionPlanProduct(
      id: 'p-mocha',
      nameAr: 'موكا',
      nameEn: 'Mocha',
      sku: 'MOC-01',
      categoryNameEn: 'Hot coffee',
    );
    final cubit = _FakePlanCubit(
      initialState: const AdminSubscriptionPlanState(
        productOptions: [latte, mocha],
      ),
    );
    await _openDialog(tester, cubit);

    await _fillRequiredFields(tester);
    final scopeChip = find.byKey(const Key('plan-product-scope-selected'));
    await tester.ensureVisible(scopeChip);
    await tester.pumpAndSettle();
    await tester.tap(scopeChip);
    await tester.pumpAndSettle();

    final choose = find.byKey(const Key('plan-products-choose'));
    await tester.ensureVisible(choose);
    await tester.pumpAndSettle();
    await tester.tap(choose);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('plan-product-search')), 'lat');
    await tester.pumpAndSettle();
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('Mocha'), findsNothing);

    await tester.tap(find.byKey(const Key('plan-product-option-p-latte')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-product-picker-apply')));
    await tester.pumpAndSettle();

    expect(find.text('Latte'), findsOneWidget);
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.productScope, 'selected');
    expect(draft.productIds, ['p-latte']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a duplicate code keeps the dialog open with an error', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakePlanCubit(
      outcome: SubscriptionPlanSaveOutcome.duplicateCode,
    );
    await _openDialog(tester, cubit);

    await _fillRequiredFields(tester);
    await _tapSave(tester);

    expect(find.text(S.subscriptionPlanDuplicateCode), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, S.subscriptionPlanSaveAction),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
