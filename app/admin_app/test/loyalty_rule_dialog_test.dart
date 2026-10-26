import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_cubit.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_rule_dialog.dart';

class _FakeRuleCubit extends AdminLoyaltyCubit {
  _FakeRuleCubit({this.outcome = LoyaltyRuleSaveOutcome.saved});

  final LoyaltyRuleSaveOutcome outcome;
  AdminLoyaltyRuleDraft? saved;

  @override
  Future<LoyaltyRuleSaveOutcome> saveRule(AdminLoyaltyRuleDraft draft) async {
    saved = draft;
    return outcome;
  }
}

const _rule = AdminLoyaltyRule(
  id: 'rule-1',
  code: 'EARN',
  nameAr: 'برنامج الكسب',
  nameEn: 'Earning program',
  pointsPerCurrencyUnit: 1,
  pointValue: 0.05,
  isActive: true,
  isCurrent: true,
);

void _setViewport(
  WidgetTester tester, [
  double width = 900,
  double height = 900,
]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openDialog(
  WidgetTester tester,
  _FakeRuleCubit cubit, {
  AdminLoyaltyRule? rule,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showLoyaltyRuleDialog(
                context: context,
                cubit: cubit,
                rule: rule,
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

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('loyalty-rule-save')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the current rule fills the form and saves the new values', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeRuleCubit();
    await _openDialog(tester, cubit, rule: _rule);

    expect(find.text(S.loyaltyProgramDialogTitle), findsOneWidget);
    expect(_fieldText(tester, 'loyalty-rule-rate'), '1');
    expect(_fieldText(tester, 'loyalty-rule-value'), '0.05');

    await tester.enterText(find.byKey(const Key('loyalty-rule-rate')), '2.5');
    await tester.enterText(find.byKey(const Key('loyalty-rule-value')), '0.1');
    await tester.pump();

    expect(
      find.text(S.loyaltyProgramPreviewEarn('100 SAR', '250')),
      findsOneWidget,
    );
    expect(
      find.text(S.loyaltyProgramPreviewWorth('100', '10 SAR')),
      findsOneWidget,
    );

    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, 'rule-1');
    expect(draft.pointsPerCurrencyUnit, 2.5);
    expect(draft.pointValue, 0.1);
    expect(draft.isActive, isTrue);
    expect(find.text(S.loyaltyProgramSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic digits and separators are accepted', (tester) async {
    _setViewport(tester);
    final cubit = _FakeRuleCubit();
    await _openDialog(tester, cubit, rule: _rule);

    await tester.enterText(find.byKey(const Key('loyalty-rule-rate')), '٢');
    await tester.enterText(find.byKey(const Key('loyalty-rule-value')), '٠٫٢٥');
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.pointsPerCurrencyUnit, 2);
    expect(draft.pointValue, 0.25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a zero rate or a negative value is refused', (tester) async {
    _setViewport(tester);
    final cubit = _FakeRuleCubit();
    await _openDialog(tester, cubit, rule: _rule);

    await tester.enterText(find.byKey(const Key('loyalty-rule-rate')), '0');
    await _tapSave(tester);
    expect(find.text(S.loyaltyProgramInvalidRate), findsOneWidget);
    expect(cubit.saved, isNull);

    await tester.enterText(find.byKey(const Key('loyalty-rule-rate')), '1');
    await tester.enterText(find.byKey(const Key('loyalty-rule-value')), '-1');
    await tester.pump();
    await _tapSave(tester);
    expect(find.text(S.loyaltyProgramInvalidValue), findsOneWidget);
    expect(cubit.saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausing the program is saved with the rule', (tester) async {
    _setViewport(tester);
    final cubit = _FakeRuleCubit();
    await _openDialog(tester, cubit, rule: _rule);

    await tester.tap(find.byKey(const Key('loyalty-rule-active')));
    await tester.pump();
    await _tapSave(tester);

    expect(cubit.saved, isNotNull);
    expect(cubit.saved!.isActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty program is created from the same form', (tester) async {
    _setViewport(tester);
    final cubit = _FakeRuleCubit();
    await _openDialog(tester, cubit);

    expect(_fieldText(tester, 'loyalty-rule-rate'), '1');
    expect(_fieldText(tester, 'loyalty-rule-value'), '0.05');
    await _tapSave(tester);

    final draft = cubit.saved;
    expect(draft, isNotNull);
    expect(draft!.id, isNull);
    expect(draft.pointsPerCurrencyUnit, 1);
    expect(draft.pointValue, 0.05);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected save keeps the dialog open with the mapped error', (
    tester,
  ) async {
    _setViewport(tester);
    final cubit = _FakeRuleCubit(outcome: LoyaltyRuleSaveOutcome.invalidRate);
    await _openDialog(tester, cubit, rule: _rule);

    await _tapSave(tester);

    expect(find.text(S.loyaltyProgramInvalidRate), findsOneWidget);
    expect(find.byKey(const Key('loyalty-rule-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
