import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_shift_dialog.dart';
import 'package:admin_app/core/models/dining_table.dart';

PosShift _openShift({
  String id = 's-1',
  String branchId = 'b1',
  double openingFloat = 100,
  double cashSales = 0,
  double cardSales = 0,
  double cashIn = 0,
  double cashOut = 0,
  int orderCount = 0,
}) {
  return PosShift(
    id: id,
    branchId: branchId,
    openingFloat: openingFloat,
    cashSales: cashSales,
    cardSales: cardSales,
    salesTotal: cashSales + cardSales,
    orderCount: orderCount,
    cashIn: cashIn,
    cashOut: cashOut,
    expectedCash: openingFloat + cashSales + cashIn - cashOut,
    currencyCode: 'SAR',
    openedByName: 'منى علي',
    openedAt: DateTime(2026, 10, 26, 8, 5),
  );
}

PosShift _closedShift({
  String id = 's-closed',
  double openingFloat = 100,
  double cashSales = 40,
  double cardSales = 20,
  double cashIn = 10,
  double cashOut = 5,
  int orderCount = 3,
  double countedCash = 145,
  String closeNote = '',
}) {
  final expected = openingFloat + cashSales + cashIn - cashOut;
  return PosShift(
    id: id,
    branchId: 'b1',
    status: PosShiftStatus.closed,
    openingFloat: openingFloat,
    cashSales: cashSales,
    cardSales: cardSales,
    salesTotal: cashSales + cardSales,
    orderCount: orderCount,
    cashIn: cashIn,
    cashOut: cashOut,
    expectedCash: expected,
    countedCash: countedCash,
    variance: countedCash - expected,
    currencyCode: 'SAR',
    openedByName: 'منى علي',
    closedByName: 'أحمد',
    openedAt: DateTime(2026, 10, 25, 8, 5),
    closedAt: DateTime(2026, 10, 25, 22),
    closeNote: closeNote,
  );
}

class _FakeShiftRepository extends AdminPosRepository {
  _FakeShiftRepository({this.shift});

  PosShift? shift;
  PosShift? openedShift;
  PosShift? movementShift;
  PosShiftException? movementError;
  PosShift? closedShiftResult;
  List<PosShift> history = const <PosShift>[];

  double? lastOpeningFloat;
  String? lastOpenNote;
  PosCashMovementKind? lastMovementKind;
  double? lastMovementAmount;
  String? lastMovementReason;
  double? lastCountedCash;
  String? lastCloseNote;
  String? lastDetailShiftId;

  @override
  Future<PosCatalog> loadCatalog({String? branchId}) async {
    return PosCatalog(branchId: branchId ?? 'b1', currencyCode: 'SAR');
  }

  @override
  Future<List<DiningTable>> loadTables(String branchId) async {
    return const <DiningTable>[];
  }

  @override
  Future<PosShift?> loadOpenShift(String branchId) async {
    final current = shift;
    if (current == null) return null;
    return current.branchId == branchId ? current : null;
  }

  @override
  Future<PosShift> openShift({
    required String branchId,
    required double openingFloat,
    String? note,
  }) async {
    lastOpeningFloat = openingFloat;
    lastOpenNote = note;
    final opened =
        openedShift ??
        _openShift(branchId: branchId, openingFloat: openingFloat);
    shift = opened;
    return opened;
  }

  @override
  Future<PosShift> recordCashMovement({
    required String shiftId,
    required PosCashMovementKind kind,
    required double amount,
    required String reason,
  }) async {
    lastMovementKind = kind;
    lastMovementAmount = amount;
    lastMovementReason = reason;
    final error = movementError;
    if (error != null) throw error;
    final updated = movementShift ?? shift ?? _openShift();
    shift = updated;
    return updated;
  }

  @override
  Future<PosShift> closeShift({
    required String shiftId,
    required double countedCash,
    String? closeNote,
  }) async {
    lastCountedCash = countedCash;
    lastCloseNote = closeNote;
    final closed = closedShiftResult ?? _closedShift(countedCash: countedCash);
    shift = null;
    return closed;
  }

  @override
  Future<List<PosShift>> loadShiftHistory(
    String branchId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return history;
  }

  @override
  Future<PosShift> loadShiftDetail(String shiftId) async {
    lastDetailShiftId = shiftId;
    for (final shift in history) {
      if (shift.id == shiftId) return shift;
    }
    return _closedShift(id: shiftId);
  }
}

Future<PosCubit> _pumpShiftDialog(
  WidgetTester tester,
  _FakeShiftRepository repository,
) async {
  final cubit = PosCubit(repository: repository);
  addTearDown(cubit.close);
  await cubit.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: BlocProvider<PosCubit>.value(
        value: cubit,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showPosShiftDialog(context, cubit: cubit),
                child: const Text('open-shift-panel'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-shift-panel'));
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('an open drawer shows its live totals and drawer actions', (
    tester,
  ) async {
    final repository = _FakeShiftRepository(
      shift: _openShift(
        openingFloat: 120,
        cashSales: 40,
        cardSales: 25,
        cashIn: 10,
        cashOut: 5,
        orderCount: 3,
      ),
    );

    final cubit = await _pumpShiftDialog(tester, repository);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pos-shift-dialog')), findsOneWidget);
    expect(find.text(S.posShiftActive), findsOneWidget);
    expect(find.text(S.posShiftExpectedCash), findsOneWidget);
    expect(find.text('165.00 SAR'), findsOneWidget);
    expect(find.text('120.00 SAR'), findsOneWidget);
    expect(find.text(S.posShiftCashSales), findsOneWidget);
    expect(find.text(S.posShiftCardSales), findsOneWidget);
    expect(find.text(S.posShiftSalesTotal), findsOneWidget);
    expect(find.text(S.posShiftOrders), findsOneWidget);
    expect(find.byKey(const Key('pos-shift-cash-in')), findsOneWidget);
    expect(find.byKey(const Key('pos-shift-cash-out')), findsOneWidget);
    expect(find.byKey(const Key('pos-shift-close')), findsOneWidget);
    expect(find.byKey(const Key('pos-shift-open-submit')), findsNothing);

    expect(cubit.state.shift?.expectedCash, 165);
  });

  testWidgets('opening a drawer sends the float and reveals the overview', (
    tester,
  ) async {
    final repository = _FakeShiftRepository();

    final cubit = await _pumpShiftDialog(tester, repository);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pos-shift-open-float')), findsOneWidget);
    expect(find.byKey(const Key('pos-shift-open-submit')), findsOneWidget);
    expect(find.byKey(const Key('pos-shift-cash-in')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('pos-shift-open-float')),
      '150',
    );
    await tester.enterText(
      find.byKey(const Key('pos-shift-open-note')),
      'درج الصباح',
    );
    await tester.tap(find.byKey(const Key('pos-shift-open-submit')));
    await tester.pumpAndSettle();

    expect(repository.lastOpeningFloat, 150);
    expect(repository.lastOpenNote, 'درج الصباح');
    expect(cubit.state.shift?.openingFloat, 150);
    expect(find.byKey(const Key('pos-shift-open-float')), findsNothing);
    expect(find.text(S.posShiftExpectedCash), findsOneWidget);
    expect(find.text('150.00 SAR'), findsWidgets);
    expect(find.byKey(const Key('pos-shift-cash-in')), findsOneWidget);
  });

  testWidgets('a cash movement updates the drawer and closes its dialog', (
    tester,
  ) async {
    final repository = _FakeShiftRepository(shift: _openShift());

    await _pumpShiftDialog(tester, repository);

    await tester.tap(find.byKey(const Key('pos-shift-cash-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos-shift-movement-dialog')), findsOneWidget);

    repository.movementShift = _openShift(openingFloat: 100, cashIn: 30);
    await tester.enterText(
      find.byKey(const Key('pos-shift-movement-amount')),
      '30',
    );
    await tester.enterText(
      find.byKey(const Key('pos-shift-movement-reason')),
      'فكة',
    );
    await tester.tap(find.byKey(const Key('pos-shift-movement-submit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pos-shift-movement-dialog')), findsNothing);
    expect(repository.lastMovementKind, PosCashMovementKind.cashIn);
    expect(repository.lastMovementAmount, 30);
    expect(repository.lastMovementReason, 'فكة');
    expect(find.text('130.00 SAR'), findsOneWidget);
    expect(find.text('30.00 SAR'), findsOneWidget);
  });

  testWidgets('a rejected cash out explains itself and keeps the form', (
    tester,
  ) async {
    final repository = _FakeShiftRepository(
      shift: _openShift(openingFloat: 100, cashSales: 20),
    );
    repository.movementError = const PosShiftException(
      PosShiftFailure.insufficientDrawerCash,
      'cash out exceeds the drawer',
    );

    await _pumpShiftDialog(tester, repository);

    await tester.tap(find.byKey(const Key('pos-shift-cash-out')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('pos-shift-movement-amount')),
      '500',
    );
    await tester.enterText(
      find.byKey(const Key('pos-shift-movement-reason')),
      'تسوية مع الصراف',
    );
    await tester.tap(find.byKey(const Key('pos-shift-movement-submit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pos-shift-movement-dialog')), findsOneWidget);
    expect(
      find.text(S.posShiftInsufficientDrawerCash),
      findsOneWidget,
      reason: 'the cashier sees the sentence, not the database text',
    );
    expect(find.textContaining('cash out exceeds the drawer'), findsNothing);
    expect(find.textContaining('22023'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pos-shift-movement-amount')))
          .controller
          ?.text,
      '500',
    );
    expect(repository.lastMovementKind, PosCashMovementKind.cashOut);
  });

  testWidgets('closing the drawer counts cash and opens the Z report', (
    tester,
  ) async {
    final repository = _FakeShiftRepository(
      shift: _openShift(
        openingFloat: 100,
        cashSales: 40,
        cashIn: 10,
        cashOut: 5,
      ),
    );

    final cubit = await _pumpShiftDialog(tester, repository);

    await tester.tap(find.byKey(const Key('pos-shift-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos-shift-close-dialog')), findsOneWidget);
    expect(find.text('145.00 SAR'), findsWidgets);
    expect(find.text(S.posShiftVarianceHint), findsOneWidget);

    repository.closedShiftResult = _closedShift(countedCash: 140);
    await tester.enterText(find.byKey(const Key('pos-shift-counted')), '140');
    await tester.pump();

    expect(find.text(S.posShiftVarianceShort), findsOneWidget);
    expect(find.text('-5.00 SAR'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pos-shift-close-submit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.lastCountedCash, 140);
    expect(cubit.state.shift, isNull);
    expect(find.byKey(const Key('pos-shift-close-dialog')), findsNothing);
    expect(find.byKey(const Key('pos-shift-report-dialog')), findsOneWidget);
    expect(find.text(S.posShiftReportZ), findsWidgets);
    expect(find.text('140.00 SAR'), findsWidgets);
    expect(find.text('-5.00 SAR'), findsOneWidget);
    // The cashier is ready for the next drawer under the report.
    expect(find.byKey(const Key('pos-shift-open-float')), findsOneWidget);
  });

  testWidgets('history lists closed shifts and opens their Z report', (
    tester,
  ) async {
    final repository = _FakeShiftRepository()
      ..history = <PosShift>[_closedShift(id: 's-9')];

    await _pumpShiftDialog(tester, repository);

    await tester.tap(find.byKey(const Key('pos-shift-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos-shift-history-dialog')), findsOneWidget);
    expect(find.text(S.posShiftHistoryEmpty), findsNothing);
    final tile = find.byKey(const Key('pos-shift-history-s-9'));
    expect(tile, findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.lastDetailShiftId, 's-9');
    expect(find.byKey(const Key('pos-shift-report-dialog')), findsOneWidget);
    expect(find.text(S.posShiftReportZ), findsWidgets);
  });
}
