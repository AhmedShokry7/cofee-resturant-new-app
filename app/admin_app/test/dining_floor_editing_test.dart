import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/tables/data/repositories/dining_tables_repository.dart';
import 'package:admin_app/features/tables/domain/entities/dining_overview.dart';
import 'package:admin_app/features/tables/domain/entities/dining_reservation_draft.dart';
import 'package:admin_app/features/tables/domain/entities/dining_table_draft.dart';
import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_cubit.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';
import 'package:admin_app/features/tables/presentation/pages/tables_page.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_messages.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_reservation_dialog.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_table_dialog.dart';

import 'helpers/stub_supabase_client.dart';

/// A floor repository the test steers: it records what the screen sent and
/// answers with the outcome the next assertion expects.
class _FakeFloorRepository implements DiningTableRepository {
  DiningOverview overview = const DiningOverview(branchId: 'b1');
  DiningLoadException? loadError;

  DiningReservationSaveOutcome reservationOutcome =
      DiningReservationSaveOutcome.saved;
  DiningReservationStatusOutcome statusOutcome =
      DiningReservationStatusOutcome.success;
  DiningTableSaveOutcome tableOutcome = DiningTableSaveOutcome.saved;

  DiningReservationDraft? savedReservation;
  DiningTableDraft? savedTable;
  DiningReservationStatus? statusCall;
  int loadCalls = 0;

  @override
  Future<DiningOverview> loadOverview({String? branchId}) async {
    loadCalls += 1;
    final error = loadError;
    if (error != null) throw error;
    return overview;
  }

  @override
  Future<DiningReservationSaveOutcome> saveReservation(
    DiningReservationDraft draft,
  ) async {
    savedReservation = draft;
    return reservationOutcome;
  }

  @override
  Future<DiningReservationStatusOutcome> setReservationStatus(
    String reservationId,
    String status,
  ) async {
    statusCall = DiningReservationStatus.fromValue(status);
    return statusOutcome;
  }

  @override
  Future<DiningTableSaveOutcome> saveTable(DiningTableDraft draft) async {
    savedTable = draft;
    return tableOutcome;
  }

  @override
  Future<DiningTableMutationOutcome> setTableActive(
    String tableId,
    bool active,
  ) async {
    return DiningTableMutationOutcome.success;
  }

  @override
  Future<DiningTableMutationOutcome> deleteTable(String tableId) async {
    return DiningTableMutationOutcome.success;
  }
}

const _table = DiningTable(
  id: 't1',
  branchId: 'b1',
  name: 'AF-1',
  capacity: 6,
  status: DiningTableStatus.available,
);

DiningReservation _booking({DateTime? reservedFor, int durationMinutes = 90}) {
  return DiningReservation(
    id: 'r1',
    branchId: 'b1',
    tableId: 't1',
    tableName: 'AF-1',
    customerName: 'ضيف',
    customerPhone: '01000000000',
    partySize: 2,
    reservedFor: reservedFor,
    durationMinutes: durationMinutes,
  );
}

DiningTablesCubit _cubitWith(_FakeFloorRepository repository) =>
    DiningTablesCubit(repository: repository);

void main() {
  group('the floor load failure', () {
    test('an empty floor with no branch is reported as no branch', () async {
      final client = StubSupabaseClient(
        payload: <String, dynamic>{
          'branch_id': null,
          'branches': <Object>[],
          'tables': <Object>[],
          'reservations': <Object>[],
          'metrics': <String, dynamic>{},
        },
      );
      final repository = DiningTablesRepository(client);

      Object? thrown;
      try {
        await repository.loadOverview();
      } catch (error) {
        thrown = error;
      }
      expect(thrown, isA<DiningLoadException>());
      expect(
        (thrown as DiningLoadException).failure,
        DiningLoadFailure.noBranch,
      );
    });

    test('a permission refusal keeps its own failure', () async {
      final repository = DiningTablesRepository(
        StubSupabaseClient(
          error: PostgrestException(
            message: 'missing permission: tables.read',
            code: '42501',
          ),
        ),
      );

      expect(
        () => repository.loadOverview(),
        throwsA(
          isA<DiningLoadException>().having(
            (e) => e.failure,
            'failure',
            DiningLoadFailure.permissionDenied,
          ),
        ),
      );
    });

    test('a seat that is too early maps to its own outcome', () async {
      final repository = DiningTablesRepository(
        StubSupabaseClient(
          payload: <String, dynamic>{'ok': false, 'reason': 'too_early'},
        ),
      );

      expect(
        await repository.setReservationStatus('r1', 'seated'),
        DiningReservationStatusOutcome.tooEarly,
      );
    });
  });

  group('the floor cubit', () {
    test(
      'a load failure keeps the reason as an enum, never as server text',
      () async {
        final repository = _FakeFloorRepository()
          ..loadError = const DiningLoadException(
            DiningLoadFailure.permissionDenied,
            'missing permission: tables.read',
          );
        final cubit = _cubitWith(repository);
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, DiningStatus.failure);
        expect(cubit.state.loadFailure, DiningLoadFailure.permissionDenied);
        expect(
          diningLoadErrorMessage(cubit.state.loadFailure),
          S.tablesPermissionDenied,
        );
      },
    );

    test('no branch in scope reaches the localized no-branch copy', () async {
      final cubit = _cubitWith(
        _FakeFloorRepository()
          ..loadError = const DiningLoadException(DiningLoadFailure.noBranch),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loadFailure, DiningLoadFailure.noBranch);
      expect(diningLoadErrorMessage(cubit.state.loadFailure), S.tablesNoBranch);
    });

    test('a successful load clears the previous failure', () async {
      final repository = _FakeFloorRepository()
        ..loadError = const DiningLoadException(DiningLoadFailure.failed);
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.loadFailure, DiningLoadFailure.failed);

      repository.loadError = null;
      await cubit.refresh();

      expect(cubit.state.status, DiningStatus.ready);
      expect(cubit.state.loadFailure, isNull);
    });

    test('refusal copy is per reason, not one shared message', () {
      expect(
        diningReservationSaveErrorMessage(
          DiningReservationSaveOutcome.invalidParty,
        ),
        S.reservationInvalidParty,
      );
      expect(
        diningReservationSaveErrorMessage(
          DiningReservationSaveOutcome.invalidTime,
        ),
        S.reservationInvalidTime,
      );
      expect(
        diningReservationStatusErrorMessage(
          DiningReservationStatusOutcome.tooEarly,
        ),
        S.reservationSeatTooEarly,
      );
    });
  });

  group('the booking editor', () {
    testWidgets('editing keeps the stored time of an already past booking', (
      tester,
    ) async {
      final stored = DateTime.now().subtract(const Duration(hours: 3));
      final repository = _FakeFloorRepository();
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDiningReservationDialog(
                  context,
                  cubit: cubit,
                  tables: const <DiningTable>[_table],
                  reservation: _booking(reservedFor: stored),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(localizedTime(stored.toLocal())), findsOneWidget);

      await tester.tap(find.byKey(const Key('dining-reservation-save')));
      await tester.pumpAndSettle();

      // The database rejects a past time only for a new booking, so the editor
      // must send the stored instant instead of moving it to now + 1 hour.
      expect(repository.savedReservation, isNotNull);
      expect(repository.savedReservation!.reservedFor, stored);
    });

    testWidgets('a stored duration outside the presets is kept and offered', (
      tester,
    ) async {
      final stored = DateTime.now().add(const Duration(days: 1));
      final repository = _FakeFloorRepository();
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDiningReservationDialog(
                  context,
                  cubit: cubit,
                  tables: const <DiningTable>[_table],
                  reservation: _booking(
                    reservedFor: stored,
                    durationMinutes: 210,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(S.reservationDurationMinutes(210)), findsOneWidget);

      await tester.tap(find.byKey(const Key('dining-reservation-save')));
      await tester.pumpAndSettle();

      expect(repository.savedReservation!.durationMinutes, 210);
    });

    testWidgets('a new booking starts ahead of now and saves', (tester) async {
      final repository = _FakeFloorRepository();
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDiningReservationDialog(
                  context,
                  cubit: cubit,
                  tables: const <DiningTable>[_table],
                  initialTable: _table,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'ضيف جديد');
      await tester.tap(find.byKey(const Key('dining-reservation-save')));
      await tester.pumpAndSettle();

      final draft = repository.savedReservation;
      expect(draft, isNotNull);
      expect(draft!.reservedFor.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('a floor with nothing bookable cannot submit a booking', (
      tester,
    ) async {
      final repository = _FakeFloorRepository();
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDiningReservationDialog(
                  context,
                  cubit: cubit,
                  tables: const <DiningTable>[],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(S.tablesEmptyHint), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('dining-reservation-save')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.savedReservation, isNull);
    });

    testWidgets('the picker stops where the board stops listing bookings', (
      tester,
    ) async {
      // 207 يعرض الحجوزات داخل [اليوم، اليوم + 30 يومًا) فقط، فكل ما بعد اليوم
      // التاسع والعشرين يُحفظ ولا يظهر في اللوحة أبدًا.
      final repository = _FakeFloorRepository();
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDiningReservationDialog(
                  context,
                  cubit: cubit,
                  tables: const <DiningTable>[_table],
                  initialTable: _table,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.reservationDate));
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final lastDay = DateTime(today.year, today.month, today.day + 29);
      final startMonth = today.add(const Duration(hours: 1));
      final expectedSteps =
          (lastDay.year - startMonth.year) * 12 +
          lastDay.month -
          startMonth.month;

      final nextMonth = find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.byIcon(Icons.chevron_right),
      );
      var steps = 0;
      while (steps < 5 &&
          tester
                  .widget<IconButton>(
                    find.ancestor(
                      of: nextMonth,
                      matching: find.byType(IconButton),
                    ),
                  )
                  .onPressed !=
              null) {
        await tester.tap(nextMonth);
        await tester.pumpAndSettle();
        steps += 1;
      }

      expect(steps, expectedSteps);
    });
  });

  group('the floor page', () {
    testWidgets('seating a later booking is decided by the database clock', (
      tester,
    ) async {
      // 207 يرفض الجلوس قبل الموعد بساعتين؛ التحقق المحلي كان يرفضه بالساعة
      // نفسها حين يختلف ساعة الجهاز، فيُمنع موظف الفرع بلا سبب.
      final repository = _FakeFloorRepository()
        ..overview = DiningOverview(
          branchId: 'b1',
          branches: const <DiningBranch>[
            DiningBranch(id: 'b1', code: 'MAIN', nameEn: 'Main'),
          ],
          tables: const <DiningTable>[_table],
          reservations: <DiningReservation>[
            _booking(reservedFor: DateTime.now().add(const Duration(days: 5))),
          ],
        );
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);
      await cubit.load();

      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TablesPage(cubit: cubit, canManage: true)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.reservationSeat));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dining-confirm')));
      await tester.pumpAndSettle();

      expect(repository.statusCall, DiningReservationStatus.seated);
      expect(tester.takeException(), isNull);
    });
  });

  group('the table editor', () {
    testWidgets('saving with no branch says so instead of doing nothing', (
      tester,
    ) async {
      final repository = _FakeFloorRepository();
      final cubit = _cubitWith(repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDiningTableDialog(
                  context,
                  cubit: cubit,
                  branchId: null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'AF-9');
      await tester.tap(find.byKey(const Key('dining-table-save')));
      await tester.pumpAndSettle();

      expect(find.text(S.tablesNoBranch), findsOneWidget);
      expect(repository.savedTable, isNull);
    });
  });
}
