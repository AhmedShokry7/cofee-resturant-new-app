import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_cubit.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_state.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_reward_dialog.dart';

class _FakeLoyaltyCubit extends AdminLoyaltyCubit {
  _FakeLoyaltyCubit({
    this.outcome = LoyaltyRewardSaveOutcome.saved,
    AdminLoyaltyState initialState = const AdminLoyaltyState(),
  }) {
    emit(initialState);
  }

  final LoyaltyRewardSaveOutcome outcome;
  AdminLoyaltyRewardDraft? saved;
  int targetLoads = 0;

  @override
  Future<LoyaltyRewardSaveOutcome> saveReward(
    AdminLoyaltyRewardDraft draft,
  ) async {
    saved = draft;
    return outcome;
  }

  @override
  Future<void> loadTargets() async {
    targetLoads++;
  }
}

const _latte = AdminLoyaltyTargetOption(
  type: AdminLoyaltyRewardType.product,
  id: 'p-latte',
  nameAr: 'لاتيه',
  nameEn: 'Latte',
  code: 'LAT-01',
  price: 18,
  categoryNameEn: 'Hot coffee',
);

const _familyBox = AdminLoyaltyTargetOption(
  type: AdminLoyaltyRewardType.bundle,
  id: 'b-family',
  nameAr: 'بوكس العائلة',
  nameEn: 'Family box',
  price: 55,
  bundleItemsCount: 3,
);

const _dailyPlan = AdminLoyaltyTargetOption(
  type: AdminLoyaltyRewardType.plan,
  id: 'pl-daily',
  nameAr: 'باقة يومية',
  nameEn: 'Daily plan',
  code: 'DAILY',
  price: 199,
  planDurationDays: 30,
  planCupsPerCycle: 10,
);

AdminLoyaltyReward _existingReward({int? stockAvailable}) => AdminLoyaltyReward(
  id: 'reward-1',
  type: AdminLoyaltyRewardType.product,
  targetId: 'p-latte',
  pointsCost: 250,
  stockAvailable: stockAvailable,
  isActive: false,
  targetNameAr: 'لاتيه',
  targetNameEn: 'Latte',
  targetCode: 'LAT-01',
  targetPrice: 18,
  categoryNameEn: 'Hot coffee',
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
  _FakeLoyaltyCubit cubit, {
  AdminLoyaltyReward? reward,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showLoyaltyRewardDialog(
                context: context,
                cubit: cubit,
                reward: reward,
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
  await tester.tap(find.byKey(const Key('loyalty-reward-save')));
  await tester.pumpAndSettle();
}

Future<void> _pickTarget(WidgetTester tester, String targetId) async {
  final chooseKey = find.byKey(const Key('loyalty-reward-choose-target'));
  final changeKey = find.byKey(const Key('loyalty-reward-change-target'));
  await tester.tap(chooseKey.evaluate().isNotEmpty ? chooseKey : changeKey);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('loyalty-reward-target-$targetId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('loyalty-reward-target-choose')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('saving without points or a target shows the errors', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(targets: [_latte]),
    );
    await _openDialog(tester, cubit);

    await _tapSave(tester);

    expect(find.text(S.loyaltyRewardInvalidPoints), findsOneWidget);
    expect(find.text(S.loyaltyRewardTargetMissing), findsOneWidget);
    expect(cubit.saved, isNull);
    expect(cubit.targetLoads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new product reward is saved with its target and quantity', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(targets: [_latte]),
    );
    await _openDialog(tester, cubit);

    await _pickTarget(tester, 'p-latte');
    expect(find.text('Latte'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('loyalty-reward-points')),
      '120',
    );
    await tester.enterText(find.byKey(const Key('loyalty-reward-stock')), '٤٠');
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, isNull);
    expect(draft.type, AdminLoyaltyRewardType.product);
    expect(draft.targetId, 'p-latte');
    expect(draft.pointsCost, 120);
    expect(draft.stockAvailable, 40);
    expect(draft.isActive, isTrue);
    expect(find.text(S.loyaltyRewardSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bundle reward keeps its own target type', (tester) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(
        targets: [_latte, _familyBox, _dailyPlan],
      ),
    );
    await _openDialog(tester, cubit);

    await tester.tap(find.byKey(const Key('loyalty-reward-type-bundle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loyalty-reward-choose-target')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loyalty-reward-target-b-family')), findsOne);
    expect(
      find.byKey(const Key('loyalty-reward-target-p-latte')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('loyalty-reward-target-b-family')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loyalty-reward-target-choose')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loyalty-reward-points')),
      '400',
    );
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.type, AdminLoyaltyRewardType.bundle);
    expect(draft.targetId, 'b-family');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plan reward can target a subscription plan', (tester) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(
        targets: [_latte, _familyBox, _dailyPlan],
      ),
    );
    await _openDialog(tester, cubit);

    await tester.tap(find.byKey(const Key('loyalty-reward-type-plan')));
    await tester.pumpAndSettle();
    await _pickTarget(tester, 'pl-daily');

    await tester.enterText(
      find.byKey(const Key('loyalty-reward-points')),
      '900',
    );
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.type, AdminLoyaltyRewardType.plan);
    expect(draft.targetId, 'pl-daily');
    expect(find.text(S.loyaltyRewardSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing reward keeps its id, points and unlimited stock', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit();
    await _openDialog(tester, cubit, reward: _existingReward());

    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, 'reward-1');
    expect(draft.type, AdminLoyaltyRewardType.product);
    expect(draft.targetId, 'p-latte');
    expect(draft.pointsCost, 250);
    expect(draft.stockAvailable, isNull);
    expect(draft.isActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a new reward without a target is refused', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(targets: [_latte]),
    );
    await _openDialog(tester, cubit);

    await tester.enterText(
      find.byKey(const Key('loyalty-reward-points')),
      '80',
    );
    await _tapSave(tester);

    expect(cubit.saved, isNull);
    expect(find.text(S.loyaltyRewardTargetMissing), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a target owned by another reward cannot be picked', (
    tester,
  ) async {
    _setViewport(tester);
    const mocha = AdminLoyaltyTargetOption(
      type: AdminLoyaltyRewardType.product,
      id: 'p-mocha',
      nameEn: 'Mocha',
      code: 'MOC-01',
      rewardId: 'other-reward',
      rewardPointsCost: 90,
    );
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(targets: [_latte, mocha]),
    );
    await _openDialog(tester, cubit);

    await tester.tap(find.byKey(const Key('loyalty-reward-choose-target')));
    await tester.pumpAndSettle();

    expect(
      find.text(S.loyaltyRewardTargetAlreadyRewardPoints(90)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('loyalty-reward-target-p-mocha')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('loyalty-reward-target-choose')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('loyalty-reward-target-p-latte')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('loyalty-reward-target-choose')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an inactive target stays visible but cannot be picked', (
    tester,
  ) async {
    _setViewport(tester);
    const pausedPlan = AdminLoyaltyTargetOption(
      type: AdminLoyaltyRewardType.plan,
      id: 'pl-paused',
      nameEn: 'Paused plan',
      isActive: false,
    );
    final cubit = _FakeLoyaltyCubit(
      initialState: const AdminLoyaltyState(targets: [_latte, pausedPlan]),
    );
    await _openDialog(tester, cubit);

    await tester.tap(find.byKey(const Key('loyalty-reward-type-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loyalty-reward-choose-target')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('loyalty-reward-target-pl-paused')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('loyalty-reward-target-pl-paused')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('loyalty-reward-target-choose')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a duplicate target keeps the dialog open with an error', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeLoyaltyCubit(
      outcome: LoyaltyRewardSaveOutcome.duplicateTarget,
      initialState: const AdminLoyaltyState(targets: [_latte]),
    );
    await _openDialog(tester, cubit);

    await _pickTarget(tester, 'p-latte');
    await tester.enterText(
      find.byKey(const Key('loyalty-reward-points')),
      '120',
    );
    await _tapSave(tester);

    expect(find.text(S.loyaltyRewardDuplicateTarget), findsOneWidget);
    expect(find.byKey(const Key('loyalty-reward-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
