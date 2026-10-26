import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/data/repositories/admin_audit_repository.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_cubit.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_state.dart';
import 'package:admin_app/features/audit/presentation/models/audit_filters.dart';

AdminAuditLog _log(int id) => AdminAuditLog(
  id: id,
  actorUserId: 'u1',
  actorName: 'Mona Ali',
  action: 'core.branch.update',
  entityType: 'branch',
  createdAt: DateTime.utc(2026, 10, 24, 9, 15),
);

class _FakeAuditRepository extends AdminAuditRepository {
  _FakeAuditRepository();

  List<AdminAuditLog> rows = const <AdminAuditLog>[];
  int total = 0;
  AdminAuditMetrics metrics = AdminAuditMetrics.empty;
  bool failRows = false;
  bool failMetrics = false;

  int loadCalls = 0;
  int metricsCalls = 0;
  String? lastSearch;
  String? lastDomain;
  bool? lastCritical;
  int? lastPage;
  int? lastPageSize;

  @override
  Future<AdminAuditPage> loadPage({
    String? search,
    String? domain,
    bool criticalOnly = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    loadCalls += 1;
    lastSearch = search;
    lastDomain = domain;
    lastCritical = criticalOnly;
    lastPage = page;
    lastPageSize = pageSize;
    if (failRows) throw StateError('rows failed');
    return AdminAuditPage(rows: rows, total: total);
  }

  @override
  Future<AdminAuditMetrics> loadMetrics() async {
    metricsCalls += 1;
    if (failMetrics) throw StateError('metrics failed');
    return metrics;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  test('the cubit loads the page with its metrics', () async {
    final repository = _FakeAuditRepository()
      ..rows = [_log(1), _log(2)]
      ..total = 12
      ..metrics = const AdminAuditMetrics(total: 12, today: 3, week: 5);
    final cubit = AdminAuditCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminAuditStatus.ready);
    expect(cubit.state.logs.map((row) => row.id), [1, 2]);
    expect(cubit.state.total, 12);
    expect(cubit.state.pages, 1);
    expect(cubit.state.metrics.today, 3);
    expect(repository.loadCalls, 1);
    expect(repository.metricsCalls, 1);
    expect(repository.lastSearch, isEmpty);
    expect(repository.lastDomain, isNull);
    expect(repository.lastCritical, isFalse);
    expect(repository.lastPage, 0);
    expect(repository.lastPageSize, 20);
  });

  test('the filters reset the page and reach the server', () async {
    final repository = _FakeAuditRepository()..total = 60;
    final cubit = AdminAuditCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    cubit.setPage(2);
    await _settle();
    expect(cubit.state.page, 2);

    cubit.setDomain(AuditDomainFilter.marketing);
    await _settle();
    expect(cubit.state.domain, AuditDomainFilter.marketing);
    expect(cubit.state.page, 0);
    expect(repository.lastDomain, 'marketing');
    expect(cubit.state.isRefreshingRows, isFalse);

    cubit.setCriticalOnly(true);
    await _settle();
    expect(cubit.state.criticalOnly, isTrue);
    expect(repository.lastCritical, isTrue);
    expect(cubit.state.page, 0);

    cubit.clearFilters();
    await _settle();
    expect(cubit.state.hasActiveFilters, isFalse);
    expect(repository.lastDomain, isNull);
    expect(repository.lastCritical, isFalse);
    expect(cubit.state.page, 0);
  });

  test(
    'typing searches after a pause and clearing it refreshes at once',
    () async {
      final repository = _FakeAuditRepository();
      final cubit = AdminAuditCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();

      final callsAfterLoad = repository.loadCalls;
      cubit.updateSearch('mona');
      expect(cubit.state.search, 'mona');
      expect(repository.loadCalls, callsAfterLoad);
      expect(repository.lastSearch, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(repository.loadCalls, callsAfterLoad + 1);
      expect(repository.lastSearch, 'mona');

      cubit.updateSearch('');
      await _settle();
      expect(cubit.state.search, isEmpty);
      expect(repository.lastSearch, isEmpty);
    },
  );

  test('a search from a later page returns to the first page', () async {
    final repository = _FakeAuditRepository()..total = 60;
    final cubit = AdminAuditCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setPage(2);
    await _settle();

    cubit.updateSearch('branch');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(cubit.state.page, 0);
    expect(repository.lastPage, 0);
    expect(repository.lastSearch, 'branch');
  });

  test('the page is clamped to the available server pages', () async {
    final repository = _FakeAuditRepository()
      ..rows = [for (var index = 0; index < 20; index++) _log(index)]
      ..total = 45;
    final cubit = AdminAuditCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    expect(cubit.state.pages, 3);
    cubit.setPage(2);
    await _settle();
    expect(cubit.state.page, 2);
    expect(repository.lastPage, 2);

    cubit.setPage(9);
    await _settle();
    expect(cubit.state.page, 2);
    expect(repository.lastPage, 2);
  });

  test('the rows still load when the metrics request fails', () async {
    final repository = _FakeAuditRepository()
      ..rows = [_log(1)]
      ..total = 1
      ..failMetrics = true;
    final cubit = AdminAuditCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminAuditStatus.ready);
    expect(cubit.state.logs, hasLength(1));
    expect(cubit.state.metrics.total, 0);
  });

  test('a failing rows request becomes a failure state', () async {
    final repository = _FakeAuditRepository()..failRows = true;
    final cubit = AdminAuditCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminAuditStatus.failure);
    expect(cubit.state.errorMessage, isNotNull);
    expect(cubit.state.logs, isEmpty);
  });
}
