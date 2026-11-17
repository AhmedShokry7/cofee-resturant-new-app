import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/hr/finance/domain/models/hr_finance_models.dart';
import 'package:admin_app/features/hr/finance/domain/repositories/hr_finance_repository.dart';
import 'package:admin_app/features/hr/finance/presentation/hr_finance_strings.dart';
import 'package:admin_app/features/hr/finance/presentation/manager/hr_finance_cubit.dart';
import 'package:admin_app/features/hr/finance/presentation/pages/hr_finance_page.dart';

class _FinanceRepository implements HrFinanceRepository {
  int advanceApprovals = 0;
  int adjustmentReviews = 0;

  @override
  Future<List<HrAdvance>> loadAdvances() async => const [
    HrAdvance(
      id: 'adv-1',
      staffId: 'staff-1',
      staffName: 'Layla Ahmed',
      amount: 1000,
      installmentAmount: 250,
      settledAmount: 0,
      outstanding: 1000,
      currency: 'SAR',
      status: 'pending',
      reason: 'Emergency',
    ),
  ];

  @override
  Future<List<HrAdjustment>> loadAdjustments() async => const [
    HrAdjustment(
      id: 'adj-1',
      staffId: 'staff-1',
      staffName: 'Layla Ahmed',
      kind: 'bonus',
      amount: 300,
      effectiveDate: '2026-11-01',
      reason: 'Performance',
      status: 'pending',
      sourceType: 'manual',
      claimed: false,
    ),
    HrAdjustment(
      id: 'adj-2',
      staffId: 'staff-1',
      staffName: 'Layla Ahmed',
      kind: 'allowance',
      amount: 100,
      effectiveDate: '2026-10-01',
      reason: 'Already snapshotted',
      status: 'approved',
      sourceType: 'manual',
      claimed: true,
    ),
  ];

  @override
  Future<List<HrDiscrepancy>> loadDiscrepancies() async => const [];
  @override
  Future<List<HrFinanceEmployee>> loadEmployees() async => const [
    HrFinanceEmployee(
      id: 'staff-1',
      name: 'Layla Ahmed',
      branchIds: ['branch-1'],
    ),
  ];
  @override
  Future<bool> loadCashierDeductionEnabled() async => false;

  @override
  Future<void> reviewAdvance(
    String id,
    bool approve,
    double? installment,
    String? note,
  ) async {
    if (approve) advanceApprovals++;
  }

  @override
  Future<void> disburseAdvance(String id, String? note) async {}
  @override
  Future<void> cancelAdvance(String id, String? note) async {}
  @override
  Future<void> createAdjustment(
    String staffId,
    String kind,
    double amount,
    String reason,
    String? date,
  ) async {}
  @override
  Future<void> reviewAdjustment(String id, bool approve, String? note) async {
    adjustmentReviews++;
  }

  @override
  Future<void> reverseAdjustment(String id, String reason) async {}
  @override
  Future<void> reviewDiscrepancy({
    required String id,
    required String action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  }) async {}
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('finance reviewer can review a pending advance', (tester) async {
    final repository = _FinanceRepository();
    final cubit = HrFinanceCubit(repository: repository);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HrFinancePage(canManage: true, cubit: cubit)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Layla Ahmed'), findsWidgets);
    await tester.tap(find.text(HrFinanceStrings.approve).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, HrFinanceStrings.save));
    await tester.pumpAndSettle();

    expect(repository.advanceApprovals, 1);
    await cubit.close();
  });

  testWidgets(
    'finance actions are hidden without permission and claimed adjustments cannot reverse',
    (tester) async {
      final cubit = HrFinanceCubit(repository: _FinanceRepository());
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HrFinancePage(canManage: false, cubit: cubit)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(HrFinanceStrings.approve), findsNothing);
      expect(find.text(HrFinanceStrings.reverse), findsNothing);
      await tester.tap(find.text(HrFinanceStrings.adjustments));
      await tester.pumpAndSettle();
      expect(find.text(HrFinanceStrings.reverse), findsNothing);
      await cubit.close();
    },
  );
}
