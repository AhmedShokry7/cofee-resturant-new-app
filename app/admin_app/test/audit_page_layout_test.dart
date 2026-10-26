import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/presentation/models/audit_filters.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_details_dialog.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_directory.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

final _metrics = AdminAuditMetrics(
  total: 25,
  today: 3,
  week: 8,
  critical: 4,
  criticalWeek: 2,
  actors: 5,
  actorsWeek: 4,
  branches: 2,
  latestAt: DateTime.utc(2026, 10, 24, 9, 15),
);

AdminAuditLog _log(
  int id, {
  String action = 'core.branch.update',
  String entityType = 'branch',
  bool critical = false,
  String? actorName = 'Mona Ali',
  List<String> rolesEn = const ['Branch manager'],
  List<String> rolesAr = const ['مدير فرع'],
  Map<String, dynamic>? oldValues = const {
    'name_ar': 'فرع المعادي',
    'name_en': 'Maadi branch',
    'is_active': true,
  },
  Map<String, dynamic>? newValues = const {
    'name_ar': 'فرع المعادي الجديد',
    'name_en': 'Maadi branch',
    'is_active': false,
  },
}) => AdminAuditLog(
  id: id,
  action: action,
  entityType: entityType,
  isCritical: critical,
  actorUserId: 'u$id',
  actorName: actorName,
  actorEmail: 'staff$id@example.com',
  actorRolesAr: rolesAr,
  actorRolesEn: rolesEn,
  entityId: 'entity-$id-123456',
  branchNameAr: 'فرع المعادي',
  branchNameEn: 'Maadi branch',
  oldValues: oldValues,
  newValues: newValues,
  createdAt: DateTime.utc(2026, 10, 24, 9, 15),
);

void _setViewport(WidgetTester tester, double width, [double height = 1100]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  List<AdminAuditLog> logs = const <AdminAuditLog>[],
  AdminAuditMetrics? metrics,
  int? total,
  int pageSize = 10,
  String search = '',
  AuditDomainFilter domain = AuditDomainFilter.all,
  bool criticalOnly = false,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: _AuditHarness(
          logs: logs,
          metrics: metrics ?? _metrics,
          total: total ?? logs.length,
          pageSize: pageSize,
          search: search,
          domain: domain,
          criticalOnly: criticalOnly,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _AuditHarness extends StatefulWidget {
  const _AuditHarness({
    required this.logs,
    required this.metrics,
    required this.total,
    required this.pageSize,
    required this.search,
    required this.domain,
    required this.criticalOnly,
  });

  final List<AdminAuditLog> logs;
  final AdminAuditMetrics metrics;
  final int total;
  final int pageSize;
  final String search;
  final AuditDomainFilter domain;
  final bool criticalOnly;

  @override
  State<_AuditHarness> createState() => _AuditHarnessState();
}

class _AuditHarnessState extends State<_AuditHarness> {
  int _page = 0;
  late String _search;
  late AuditDomainFilter _domain;
  late bool _criticalOnly;
  int clearCalls = 0;

  @override
  void initState() {
    super.initState();
    _search = widget.search;
    _domain = widget.domain;
    _criticalOnly = widget.criticalOnly;
  }

  int get _pages => widget.total <= 0
      ? 0
      : (widget.total + widget.pageSize - 1) ~/ widget.pageSize;

  List<AdminAuditLog> get _rows {
    final start = (_page * widget.pageSize).clamp(0, widget.logs.length);
    final end = (start + widget.pageSize).clamp(0, widget.logs.length);
    return widget.logs.sublist(start, end);
  }

  void _clearFilters() {
    setState(() {
      clearCalls += 1;
      _search = '';
      _domain = AuditDomainFilter.all;
      _criticalOnly = false;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuditPageBody(
      metrics: widget.metrics,
      refreshing: false,
      onRefresh: () {},
      directory: AuditDirectory(
        logs: _rows,
        total: widget.total,
        page: _page,
        pages: _pages,
        pageSize: widget.pageSize,
        search: _search,
        domain: _domain,
        criticalOnly: _criticalOnly,
        isRefreshingRows: false,
        onSearchChanged: (value) => setState(() => _search = value.trim()),
        onDomainChanged: (value) => setState(() {
          _domain = value;
          _page = 0;
        }),
        onCriticalChanged: (value) => setState(() {
          _criticalOnly = value;
          _page = 0;
        }),
        onClearFilters: _clearFilters,
        onPageChanged: (page) => setState(() => _page = page),
        onOpen: (log) => showAuditDetailsDialog(context: context, log: log),
      ),
    );
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the wide page shows the metrics, filters and audit table', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      logs: [
        _log(1),
        _log(
          2,
          action: 'marketing.coupon.delete',
          entityType: 'coupon',
          critical: true,
          actorName: 'Omar Hassan',
          rolesEn: const ['Owner'],
          rolesAr: const ['المالك'],
          oldValues: const {'code': 'EID20'},
          newValues: null,
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminPageFrame), findsOneWidget);
    expect(find.text(S.auditLog), findsOneWidget);
    expect(find.text(S.auditLogDescription), findsOneWidget);
    expect(find.byKey(const Key('audit-refresh')), findsOneWidget);

    expect(find.text(S.auditMetricTotal), findsOneWidget);
    expect(find.text(S.auditMetricToday), findsWidgets);
    expect(find.text(S.auditMetricCritical), findsOneWidget);
    expect(find.text(S.auditMetricActors), findsOneWidget);
    expect(find.text('25'), findsOneWidget);

    expect(find.text(S.auditFilterAllDomains), findsOneWidget);
    expect(find.text(S.auditFilterCritical), findsOneWidget);
    expect(find.text(S.auditTableEvent), findsOneWidget);
    expect(find.text(S.auditTableActor), findsOneWidget);
    expect(find.text(S.auditTableBranch), findsOneWidget);
    expect(find.text(S.auditTableTime), findsOneWidget);
    expect(find.text(S.auditTableSensitivity), findsOneWidget);

    expect(find.byKey(const Key('audit-row-1')), findsOneWidget);
    expect(find.byKey(const Key('audit-row-2')), findsOneWidget);
    expect(find.byKey(const Key('audit-card-1')), findsNothing);
    expect(
      find.text('${S.auditActionBranchUpdate} • Maadi branch'),
      findsOneWidget,
    );
    expect(find.text('${S.auditActionCouponDelete} • EID20'), findsOneWidget);
    expect(find.text('Mona Ali'), findsOneWidget);
    expect(find.text('Branch manager'), findsOneWidget);
    expect(find.text('Maadi branch'), findsNWidgets(2));
    expect(find.text(S.auditCriticalBadge), findsOneWidget);
    expect(find.text(S.auditNormalBadge), findsOneWidget);
    expect(find.text(S.auditRowsLabel(1, 2, 2)), findsOneWidget);
  });

  testWidgets('the narrow page switches to readable audit cards', (
    tester,
  ) async {
    _setViewport(tester, 420, 900);
    await _pumpPage(tester, logs: [_log(1), _log(2, critical: true)]);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('audit-card-1')), findsOneWidget);
    expect(find.byKey(const Key('audit-card-2')), findsOneWidget);
    expect(find.byKey(const Key('audit-row-1')), findsNothing);
    expect(find.text(S.auditTableEvent), findsNothing);
    expect(find.text('Mona Ali'), findsNWidgets(2));
    expect(find.text(S.auditCriticalBadge), findsOneWidget);
    expect(find.text(S.auditMetricTotal), findsOneWidget);
  });

  testWidgets('an empty log explains what will appear here', (tester) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, metrics: AdminAuditMetrics.empty);

    expect(tester.takeException(), isNull);
    expect(find.text(S.auditEmpty), findsOneWidget);
    expect(find.text(S.auditEmptyHint), findsOneWidget);
    expect(find.text(S.auditNoMatches), findsNothing);
    expect(find.text(S.clearFilters), findsNothing);
  });

  testWidgets('a search without a match offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(
      tester,
      search: 'missing',
      metrics: AdminAuditMetrics.empty,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.auditNoMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);

    await tester.tap(find.text(S.clearFilters));
    await tester.pumpAndSettle();

    expect(find.text(S.auditNoMatches), findsNothing);
    expect(find.text(S.auditEmpty), findsOneWidget);
  });

  testWidgets('the toolbar filters by area and sensitivity', (tester) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, logs: [_log(1), _log(2)], total: 2);

    await tester.tap(find.text(S.auditFilterAllDomains));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.auditDomainMarketing));
    await tester.pumpAndSettle();

    expect(find.text(S.auditDomainMarketing), findsOneWidget);
    expect(find.byTooltip(S.clearFilters), findsOneWidget);

    await tester.tap(find.text(S.auditFilterCritical));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(S.clearFilters));
    await tester.pumpAndSettle();

    expect(find.text(S.auditFilterAllDomains), findsOneWidget);
    expect(find.byTooltip(S.clearFilters), findsNothing);
  });

  testWidgets('the directory pages through the server rows', (tester) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      logs: [for (var index = 1; index <= 7; index++) _log(index)],
      total: 7,
      pageSize: 5,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('audit-row-1')), findsOneWidget);
    expect(find.byKey(const Key('audit-row-6')), findsNothing);
    expect(find.text(S.auditRowsLabel(1, 5, 7)), findsOneWidget);

    await tester.tap(find.byTooltip(S.nextPage));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audit-row-6')), findsOneWidget);
    expect(find.byKey(const Key('audit-row-7')), findsOneWidget);
    expect(find.byKey(const Key('audit-row-1')), findsNothing);
    expect(find.text(S.auditRowsLabel(6, 7, 7)), findsOneWidget);
  });

  testWidgets('tapping a row opens the readable event details', (tester) async {
    _setViewport(tester, 1500);
    await _pumpPage(tester, logs: [_log(1)]);

    await tester.tap(find.byKey(const Key('audit-row-1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('audit-details-dialog')), findsOneWidget);
    expect(find.text(S.auditDetailsTitle), findsOneWidget);
    expect(find.text(S.auditDetailsChanges), findsOneWidget);
    expect(find.byKey(const Key('audit-change-name_ar')), findsOneWidget);
    expect(find.text(S.auditDetailsBefore), findsNWidgets(2));
    expect(find.text(S.auditDetailsAfter), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('audit-details-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audit-details-dialog')), findsNothing);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      logs: [
        _log(1),
        _log(2, action: 'stock.adjust', entityType: 'stock'),
      ],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.auditLog), findsOneWidget);
    expect(find.text(S.auditMetricTotal), findsOneWidget);
    expect(
      find.text('${S.auditActionBranchUpdate} • فرع المعادي الجديد'),
      findsOneWidget,
    );
    expect(find.text('Mona Ali'), findsWidgets);
    expect(find.byKey(const Key('audit-card-1')), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      logs: [_log(1), _log(2, critical: true)],
      dark: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('audit-row-2')), findsOneWidget);
    expect(find.text(S.auditMetricTotal), findsOneWidget);
  });
}
