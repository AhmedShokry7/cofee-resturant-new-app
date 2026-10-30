import 'dart:async';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_adjustments_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_advances_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_discrepancies_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_discrepancy_action.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع مال وهمي يسجّل ما يُرسَل فعلًا، لأن الاختبار هنا على ما تلمسه
/// الشاشة من أرقام وقرارات، لا على نص SQL.
class _MoneyFake implements HrMoneyRepository {
  List<HrAdvance> advances = <HrAdvance>[
    HrAdvance.fromJson(<String, dynamic>{
      'id': 'adv-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'amount': 900,
      'status': 'pending',
    }),
  ];
  List<HrAdjustment> adjustments = <HrAdjustment>[
    HrAdjustment.fromJson(<String, dynamic>{
      'id': 'adj-1',
      'staff_id': 's-1',
      'staff_name': 'سارة',
      'kind': 'deduction',
      'amount': 120,
      'status': 'pending',
      'source_type': 'manual',
    }),
  ];
  List<HrDiscrepancy> discrepancies = <HrDiscrepancy>[
    HrDiscrepancy.fromJson(<String, dynamic>{
      'id': 'dis-1',
      'shift_id': 'sh-1',
      'branch_id': 'b-1',
      'branch_name_ar': 'الروضة',
      'drawer_cashier_name': 'نادر',
      'signed_variance': -35,
      'amount': 35,
      'status': 'pending_review',
    }),
  ];

  Object? failure;
  int advanceLoads = 0;
  int discrepancyLoads = 0;
  final List<String> reviewCalls = <String>[];
  Completer<void>? gate;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<HrAdvance>> loadAdvances({
    String? status,
    String? staffId,
    int limit = 50,
  }) async {
    advanceLoads += 1;
    if (failure != null) throw failure!;
    return advances;
  }

  @override
  Future<HrReceipt> reviewAdvance({
    required String advanceId,
    required bool approve,
    double? installment,
    String? note,
  }) async {
    reviewCalls.add('$advanceId:${approve ? 'approve' : 'reject'}');
    await gate?.future;
    if (failure != null) throw failure!;
    advances = <HrAdvance>[
      for (final advance in advances)
        if (advance.id == advanceId)
          HrAdvance.fromJson(<String, dynamic>{
            'id': advanceId,
            'staff_id': advance.staffId,
            'staff_name': advance.staffName,
            'amount': advance.amount,
            'installment_amount': installment ?? 0,
            'status': approve ? 'approved' : 'rejected',
          })
        else
          advance,
    ];
    return HrReceipt.fromJson(<String, dynamic>{
      'id': advanceId,
      'status': approve ? 'approved' : 'rejected',
    });
  }

  @override
  Future<List<HrAdjustment>> loadAdjustments({
    String? status,
    String? staffId,
    String? sourceType,
    int limit = 60,
  }) async {
    if (failure != null) throw failure!;
    return adjustments;
  }

  @override
  Future<HrReceipt> createAdjustment({
    required String staffId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
    double? quantity,
  }) async {
    await gate?.future;
    if (failure != null) throw failure!;
    return HrReceipt.fromJson(<String, dynamic>{'id': 'adj-new'});
  }

  @override
  Future<List<HrDiscrepancy>> loadDiscrepancies({
    String? status,
    String? branchId,
    int limit = 60,
  }) async {
    discrepancyLoads += 1;
    if (failure != null) throw failure!;
    return discrepancies;
  }

  /// القرار يعيد الصف كما صار، فلا تملك الشاشة أن تضيف حسمًا لم تعتره القاعدة.
  @override
  Future<HrDiscrepancy> reviewDiscrepancy({
    required String discrepancyId,
    required String action,
    String? note,
    String? evidence,
    String? attributedStaffId,
    double? deductionAmount,
  }) async {
    reviewCalls.add(
      '$discrepancyId:$action:'
      '${attributedStaffId ?? '-'}:${deductionAmount ?? '-'}',
    );
    if (failure != null) throw failure!;
    final before = discrepancies.firstWhere((d) => d.id == discrepancyId);
    final next = <String, dynamic>{
      'id': before.id,
      'shift_id': before.shiftId,
      'branch_id': before.branchId,
      'branch_name_ar': before.branchName,
      'drawer_cashier_name': before.drawerCashierName,
      'signed_variance': before.signedVariance,
      'amount': before.amount,
      'attributed_staff_id': attributedStaffId,
      'note': note,
      'deduction_adjustment_id': action == 'deduct' ? 'adj-from-shift' : null,
      'status': switch (action) {
        'explain' => 'explained',
        'reconcile' => 'reconciliation_required',
        'confirm' => 'confirmed',
        'reject' => 'rejected',
        'deduct' => 'deduction_approved',
        _ => 'closed',
      },
    };
    discrepancies = <HrDiscrepancy>[
      for (final row in discrepancies)
        if (row.id == discrepancyId) HrDiscrepancy.fromJson(next) else row,
    ];
    return discrepancies.firstWhere((d) => d.id == discrepancyId);
  }
}

void main() {
  late _MoneyFake money;

  setUp(() {
    money = _MoneyFake();
  });

  group('refusal keeps the screen honest', () {
    test('a refused read keeps the rows already seen, never zeros', () async {
      final cubit = HrAdvancesCubit(repository: money);
      await cubit.reload();
      expect(cubit.state.items, hasLength(1));

      money.failure = HrRefusal(
        sqlState: '42501',
        message: 'missing permission: hr.finance.adjust',
      );
      await cubit.reload();

      expect(cubit.state.status, HrLoadStatus.failure);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.failure?.isPermission, isTrue);
    });

    test('a refused write surfaces its text and re-reads nothing', () async {
      final cubit = HrAdvancesCubit(repository: money);
      await cubit.reload();
      final loadsAfterRead = money.advanceLoads;
      money.failure = HrRefusal(
        sqlState: '23514',
        message: 'you cannot review your own advance request',
      );

      final done = await cubit.review(advanceId: 'adv-1', approve: true);

      expect(done, isFalse);
      expect(cubit.state.writing, HrWriteStatus.done);
      expect(cubit.state.receipt, isNull);
      expect(cubit.state.failure?.sqlState, '23514');
      expect(cubit.state.items.first.status, 'pending');
      expect(money.advanceLoads, loadsAfterRead);
    });

    test(
      'an approved refusal label is the rule’s, not a generic error',
      () async {
        final cubit = HrAdjustmentsCubit(repository: money);
        await cubit.reload();
        money.failure = HrRefusal(
          sqlState: '23505',
          message: 'this adjustment is already part of a payroll run',
        );

        await cubit.create(
          staffId: 's-1',
          kind: 'deduction',
          amount: 50,
          reason: 'تجاوز السقف',
        );

        expect(cubit.state.failure?.isDuplicate, isTrue);
        expect(
          hrRefusalMessage(cubit.state.failure!),
          S.hrAdjustmentAlreadyInRun,
          reason: 'سطر في لقطة معتمدة يُصحَّح بقيد لاحق، ولا يُعكس',
        );
      },
    );
  });

  group('money safety at the client seam', () {
    test('a shortage explained creates no deduction anywhere', () async {
      final cubit = HrDiscrepanciesCubit(repository: money);
      await cubit.reload();

      final done = await cubit.review(
        discrepancyId: 'dis-1',
        action: HrDiscrepancyAction.explain,
        note: 'فرق حساب لا عجز',
        evidence: 'شريط الورديّة',
      );

      expect(done, isTrue);
      expect(money.reviewCalls, ['dis-1:explain:-:-']);
      expect(cubit.state.items.single.hasDeduction, isFalse);
      expect(cubit.state.items.single.signedVariance, -35);
    });

    test('deduction is only ever sent when the manager types one', () async {
      final cubit = HrDiscrepanciesCubit(repository: money);
      await cubit.reload();

      await cubit.review(
        discrepancyId: 'dis-1',
        action: HrDiscrepancyAction.confirm,
        note: 'عجز مثبّت',
        attributedStaffId: 's-2',
      );

      expect(money.reviewCalls.single, 'dis-1:confirm:s-2:-');
      expect(cubit.state.items.single.status, 'confirmed');
      expect(cubit.state.items.single.hasDeduction, isFalse);
    });

    test('a second write cannot pile onto one in flight', () async {
      final cubit = HrAdvancesCubit(repository: money);
      await cubit.reload();
      money.gate = Completer<void>();

      final first = cubit.review(advanceId: 'adv-1', approve: true);
      final second = await cubit.review(advanceId: 'adv-1', approve: true);

      expect(second, isFalse);
      money.gate!.complete();
      await first;
      expect(money.reviewCalls, ['adv-1:approve']);
    });

    test('a successful write re-reads the rows from the rule', () async {
      final cubit = HrAdvancesCubit(repository: money);
      await cubit.reload();
      final loadsBefore = money.advanceLoads;

      final done = await cubit.review(advanceId: 'adv-1', approve: true);

      expect(done, isTrue);
      expect(cubit.state.receipt?.status, 'approved');
      expect(cubit.state.items.single.status, 'approved');
      expect(money.advanceLoads, greaterThan(loadsBefore));
    });
  });

  group('filters go to the rule, not to the list', () {
    test('a status filter reloads instead of hiding rows locally', () async {
      final cubit = HrAdvancesCubit(repository: money);
      await cubit.reload();
      final loadsBefore = money.advanceLoads;

      await cubit.setStatus('pending');

      expect(cubit.status, 'pending');
      expect(money.advanceLoads, loadsBefore + 1);
    });

    test('the branch of a discrepancy is a query, not a guess', () async {
      final cubit = HrDiscrepanciesCubit(repository: money);
      await cubit.reload();

      await cubit.setBranch('b-2');

      expect(cubit.branchId, 'b-2');
      expect(money.discrepancyLoads, 2);
    });
  });

  test('a list state never claims ready while a write is in the air', () async {
    final cubit = HrAdvancesCubit(repository: money);
    await cubit.reload();
    money.gate = Completer<void>();

    final write = cubit.review(advanceId: 'adv-1', approve: false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isWriting, isTrue);
    expect(cubit.state.status, HrLoadStatus.ready);

    money.gate!.complete();
    await write;
    expect(cubit.state.writing, HrWriteStatus.done);
    expect(cubit.state, isA<HrListState<HrAdvance>>());
  });
}
