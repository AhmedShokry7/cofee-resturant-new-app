import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/kitchen/data/models/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/data/repositories/admin_kitchen_repository.dart';
import 'package:admin_app/features/kitchen/data/services/kitchen_realtime_feed.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_cubit.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_state.dart';

final DateTime _now = DateTime.utc(2026, 10, 24, 10);

const _filters = AdminKitchenFilters(
  branches: <AdminKitchenBranchOption>[
    AdminKitchenBranchOption(
      id: 'b1',
      code: 'MAADI',
      nameAr: 'المعادي',
      nameEn: 'Maadi',
    ),
    AdminKitchenBranchOption(
      id: 'b2',
      code: 'NASR',
      nameAr: 'مدينة نصر',
      nameEn: 'Nasr City',
    ),
  ],
);

AdminKitchenTicket _ticket(String id) => AdminKitchenTicket(
  id: id,
  orderId: 'o-$id',
  orderNumber: '#$id',
  placedAt: _now.subtract(const Duration(minutes: 4)),
  branchId: 'b1',
  itemCount: 1,
);

class _FakeKitchenRepository extends AdminKitchenRepository {
  List<AdminKitchenTicket> tickets = <AdminKitchenTicket>[];
  int total = 0;
  AdminKitchenMetrics metrics = AdminKitchenMetrics.empty;
  AdminKitchenFilters filters = _filters;

  bool failBoard = false;
  bool failMetrics = false;
  bool failFilters = false;

  int boardCalls = 0;
  int metricsCalls = 0;
  int filtersCalls = 0;

  String? lastSearch;
  String? lastBranchId;
  String? lastMetricsBranchId;

  Completer<void>? boardGate;
  Completer<void>? ticketGate;

  KitchenMutationOutcome ticketOutcome = KitchenMutationOutcome.success;
  KitchenMutationOutcome itemOutcome = KitchenMutationOutcome.success;
  String? lastTicketId;
  KitchenTicketStatus? lastTicketStatus;
  String? lastItemId;
  KitchenItemStatus? lastItemStatus;

  @override
  Future<AdminKitchenBoard> loadBoard({
    String? search,
    String? branchId,
    int limit = 150,
  }) async {
    boardCalls += 1;
    lastSearch = search;
    lastBranchId = branchId;
    await boardGate?.future;
    if (failBoard) throw StateError('board failed');
    return AdminKitchenBoard(tickets: tickets, total: total);
  }

  @override
  Future<AdminKitchenMetrics> loadMetrics({String? branchId}) async {
    metricsCalls += 1;
    lastMetricsBranchId = branchId;
    if (failMetrics) throw StateError('metrics failed');
    return metrics;
  }

  @override
  Future<AdminKitchenFilters> loadFilters() async {
    filtersCalls += 1;
    if (failFilters) throw StateError('filters failed');
    return filters;
  }

  @override
  Future<KitchenMutationOutcome> setTicketStatus(
    String ticketId,
    KitchenTicketStatus status,
  ) async {
    lastTicketId = ticketId;
    lastTicketStatus = status;
    await ticketGate?.future;
    return ticketOutcome;
  }

  @override
  Future<KitchenMutationOutcome> setItemStatus(
    String itemId,
    KitchenItemStatus status,
  ) async {
    lastItemId = itemId;
    lastItemStatus = status;
    return itemOutcome;
  }
}

class _FakeKitchenFeed extends KitchenRealtimeFeed {
  VoidCallback? _handler;
  bool started = false;
  bool disposed = false;

  @override
  bool get isActive => started && !disposed;

  @override
  void start(VoidCallback onChanged) {
    started = true;
    _handler = onChanged;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _handler = null;
  }

  void emitChange() => _handler?.call();
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('AdminKitchenCubit', () {
    test('load fetches the board, metrics and filters together', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[_ticket('t1'), _ticket('t2')]
        ..total = 2
        ..metrics = const AdminKitchenMetrics(
          queued: 2,
          active: 2,
          oldestWaitMinutes: 4,
        );
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _FakeKitchenFeed(),
        clock: () => _now,
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminKitchenStatus.ready);
      expect(cubit.state.tickets, hasLength(2));
      expect(cubit.state.total, 2);
      expect(cubit.state.metrics.queued, 2);
      expect(cubit.state.filters.hasBranches, isTrue);
      expect(cubit.state.hasData, isTrue);
      expect(cubit.state.now, _now);
      expect(cubit.state.lastUpdatedAt, _now);
      expect(repository.boardCalls, 1);
      expect(repository.metricsCalls, 1);
      expect(repository.filtersCalls, 1);
      expect(cubit.state.ticketsFor(KitchenTicketStatus.queued), hasLength(2));
    });

    test('search is debounced, trimmed and cleared immediately', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[_ticket('t1')]
        ..total = 1;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _FakeKitchenFeed(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(repository.boardCalls, 1);

      cubit.updateSearch(' latte ');
      expect(cubit.state.search, 'latte');
      expect(cubit.state.isRefreshing, isFalse);
      expect(repository.boardCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repository.boardCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.boardCalls, 2);
      expect(repository.lastSearch, 'latte');
      expect(repository.metricsCalls, 1);

      cubit.updateSearch('');
      await _settle();
      expect(cubit.state.search, isEmpty);
      expect(repository.boardCalls, 3);
      expect(repository.lastSearch, isEmpty);
    });

    test(
      'a branch reloads the summary and clearFilters resets everything',
      () async {
        final repository = _FakeKitchenRepository()
          ..tickets = <AdminKitchenTicket>[_ticket('t1')]
          ..total = 1;
        final cubit = AdminKitchenCubit(
          repository: repository,
          realtimeFeed: _FakeKitchenFeed(),
        );
        addTearDown(cubit.close);
        await cubit.load();

        cubit.setBranch(null);
        await _settle();
        expect(repository.boardCalls, 1);

        cubit.setBranch('b1');
        await _settle();
        expect(cubit.state.branchId, 'b1');
        expect(repository.lastBranchId, 'b1');
        expect(repository.lastMetricsBranchId, 'b1');
        expect(repository.boardCalls, 2);
        expect(repository.metricsCalls, 2);

        cubit.updateSearch('mocha');
        await Future<void>.delayed(const Duration(milliseconds: 420));
        expect(repository.boardCalls, 3);
        expect(repository.metricsCalls, 2);

        cubit.clearFilters();
        await _settle();
        expect(cubit.state.search, isEmpty);
        expect(cubit.state.branchId, isNull);
        expect(cubit.state.hasActiveFilters, isFalse);
        expect(repository.boardCalls, 4);
        expect(repository.metricsCalls, 3);
        expect(repository.lastBranchId, isNull);
      },
    );

    test('a summary failure keeps the board usable', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[_ticket('t1')]
        ..total = 1
        ..failMetrics = true
        ..failFilters = true;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _FakeKitchenFeed(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminKitchenStatus.ready);
      expect(cubit.state.tickets, hasLength(1));
      expect(cubit.state.metrics, AdminKitchenMetrics.empty);
      expect(cubit.state.filters.hasBranches, isFalse);
      expect(cubit.state.errorMessage, isNull);
    });

    test('a board failure is retryable', () async {
      final repository = _FakeKitchenRepository()..failBoard = true;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _FakeKitchenFeed(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminKitchenStatus.failure);
      expect(cubit.state.errorMessage, contains('board failed'));
      expect(cubit.state.isRefreshing, isFalse);

      repository
        ..failBoard = false
        ..tickets = <AdminKitchenTicket>[_ticket('t1')]
        ..total = 1;
      await cubit.load();

      expect(cubit.state.status, AdminKitchenStatus.ready);
      expect(cubit.state.tickets, hasLength(1));
      expect(cubit.state.errorMessage, isNull);
    });

    test(
      'a failed refresh keeps the shown tickets and reports inline',
      () async {
        final repository = _FakeKitchenRepository()
          ..tickets = <AdminKitchenTicket>[_ticket('t1')]
          ..total = 1;
        final cubit = AdminKitchenCubit(
          repository: repository,
          realtimeFeed: _FakeKitchenFeed(),
        );
        addTearDown(cubit.close);
        await cubit.load();

        repository.failBoard = true;
        await cubit.refresh();

        expect(cubit.state.status, AdminKitchenStatus.ready);
        expect(cubit.state.tickets, hasLength(1));
        expect(cubit.state.errorMessage, contains('board failed'));
        expect(cubit.state.isRefreshing, isFalse);

        repository.failBoard = false;
        await cubit.refresh();
        expect(cubit.state.errorMessage, isNull);
      },
    );

    test(
      'a manual refresh shows progress while a live one stays quiet',
      () async {
        final repository = _FakeKitchenRepository()
          ..tickets = <AdminKitchenTicket>[_ticket('t1')]
          ..total = 1;
        final cubit = AdminKitchenCubit(
          repository: repository,
          realtimeFeed: _FakeKitchenFeed(),
          clock: () => _now,
        );
        addTearDown(cubit.close);
        await cubit.load();

        repository.boardGate = Completer<void>();
        final manual = cubit.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isRefreshing, isTrue);
        repository.boardGate!.complete();
        await manual;
        expect(cubit.state.isRefreshing, isFalse);
        expect(cubit.state.lastUpdatedAt, _now);
        expect(repository.boardCalls, 2);

        repository.boardGate = Completer<void>();
        final live = cubit.refreshLive();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isRefreshing, isFalse);
        repository.boardGate!.complete();
        await live;
        expect(cubit.state.isRefreshing, isFalse);
        expect(repository.boardCalls, 3);
        expect(repository.metricsCalls, 3);
      },
    );

    test(
      'ticket changes are guarded, cleared and refresh on success',
      () async {
        final repository = _FakeKitchenRepository()
          ..tickets = <AdminKitchenTicket>[_ticket('t1')]
          ..total = 1;
        final cubit = AdminKitchenCubit(
          repository: repository,
          realtimeFeed: _FakeKitchenFeed(),
        );
        addTearDown(cubit.close);
        await cubit.load();

        repository.ticketGate = Completer<void>();
        final pending = cubit.setTicketStatus(
          't1',
          KitchenTicketStatus.preparing,
        );
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isTicketBusy('t1'), isTrue);

        final duplicate = await cubit.setTicketStatus(
          't1',
          KitchenTicketStatus.ready,
        );
        expect(duplicate, KitchenMutationOutcome.failed);
        expect(repository.lastTicketStatus, KitchenTicketStatus.preparing);

        repository.ticketGate!.complete();
        final outcome = await pending;
        expect(outcome, KitchenMutationOutcome.success);
        expect(cubit.state.isTicketBusy('t1'), isFalse);
        expect(repository.lastTicketId, 't1');
        expect(repository.boardCalls, 2);
      },
    );

    test('a rejected ticket change keeps the board unchanged', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[_ticket('t1')]
        ..total = 1
        ..ticketOutcome = KitchenMutationOutcome.invalidTransition;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _FakeKitchenFeed(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      final outcome = await cubit.setTicketStatus(
        't1',
        KitchenTicketStatus.completed,
      );

      expect(outcome, KitchenMutationOutcome.invalidTransition);
      expect(cubit.state.isTicketBusy('t1'), isFalse);
      expect(repository.boardCalls, 1);
    });

    test('item changes refresh only when the RPC succeeds', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[_ticket('t1')]
        ..total = 1
        ..itemOutcome = KitchenMutationOutcome.notFound;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _FakeKitchenFeed(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      final missing = await cubit.setItemStatus('i1', KitchenItemStatus.ready);
      expect(missing, KitchenMutationOutcome.notFound);
      expect(cubit.state.isItemBusy('i1'), isFalse);
      expect(repository.boardCalls, 1);

      repository.itemOutcome = KitchenMutationOutcome.success;
      final ready = await cubit.setItemStatus('i1', KitchenItemStatus.ready);
      expect(ready, KitchenMutationOutcome.success);
      expect(repository.lastItemId, 'i1');
      expect(repository.lastItemStatus, KitchenItemStatus.ready);
      expect(cubit.state.isItemBusy('i1'), isFalse);
      expect(repository.boardCalls, 2);
    });

    test('the live feed reloads the board quietly', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[_ticket('t1')]
        ..total = 1;
      final feed = _FakeKitchenFeed();
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: feed,
      );
      addTearDown(cubit.close);
      await cubit.load();

      cubit.startLiveUpdates();
      cubit.startLiveUpdates();
      expect(feed.started, isTrue);

      feed.emitChange();
      await _settle();

      expect(repository.boardCalls, 2);
      expect(repository.metricsCalls, 2);
      expect(cubit.state.isRefreshing, isFalse);
    });

    test('tick moves the clock forward for the elapsed timers', () async {
      var now = _now;
      final cubit = AdminKitchenCubit(
        repository: _FakeKitchenRepository(),
        realtimeFeed: _FakeKitchenFeed(),
        clock: () => now,
      );
      addTearDown(cubit.close);

      expect(cubit.state.now, _now);

      now = _now.add(const Duration(minutes: 1));
      cubit.tick();
      expect(cubit.state.now, now);
    });

    test('closing cancels the pending search and disposes the feed', () async {
      final repository = _FakeKitchenRepository();
      final feed = _FakeKitchenFeed();
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: feed,
      );
      await cubit.load();
      cubit.startLiveUpdates();
      cubit.updateSearch('mocha');

      await cubit.close();

      await Future<void>.delayed(const Duration(milliseconds: 420));
      expect(repository.boardCalls, 1);
      expect(feed.disposed, isTrue);
      expect(cubit.isClosed, isTrue);
    });
  });
}
