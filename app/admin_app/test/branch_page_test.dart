import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_draft.dart';
import 'package:admin_app/features/branches/data/models/admin_branch_metrics.dart';
import 'package:admin_app/features/branches/data/repositories/admin_branch_repository.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_state.dart';
import 'package:admin_app/features/branches/presentation/models/branch_filter.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_data_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

const _metrics = AdminBranchMetrics(
  total: 3,
  active: 2,
  inactive: 1,
  withoutLocation: 1,
  zonesCovered: 4,
  orders30d: 128,
  staffAssigned: 6,
);

AdminBranch _branch(
  int index, {
  bool isActive = true,
  bool withLocation = true,
  int zoneCount = 1,
  int staffCount = 2,
  int orders30d = 10,
}) {
  return AdminBranch(
    id: 'b$index',
    code: 'BR-$index',
    nameAr: 'فرع $index',
    nameEn: 'Branch $index',
    address: 'Address $index',
    latitude: withLocation ? 24.7 + index : null,
    longitude: withLocation ? 46.6 + index : null,
    phone: '+966500000$index',
    isActive: isActive,
    opensAt: '08:00:00',
    closesAt: '23:00:00',
    zoneCount: zoneCount,
    staffCount: staffCount,
    orders30d: orders30d,
  );
}

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  List<AdminBranch> branches = const <AdminBranch>[],
  AdminBranchMetrics metrics = _metrics,
  String search = '',
  bool canManage = true,
  bool canManagePricing = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: BranchPageBody(
          branches: branches,
          metrics: metrics,
          search: search,
          onSearchChanged: (_) {},
          canManage: canManage,
          canManagePricing: canManagePricing,
          onAdd: () {},
          onEdit: (_) {},
          onChangeImage: (_) {},
          onManageDelivery: (_) {},
          onManagePricing: (_) {},
          onToggleActive: (_) {},
          onDelete: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openBranchDialog(
  WidgetTester tester, {
  required Future<BranchSaveOutcome> Function(AdminBranchDraft) onSave,
  AdminBranch? initialBranch,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => BranchDataDialog(
                  initialBranch: initialBranch,
                  onSave: onSave,
                ),
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

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(_field('${S.branchCode} *'), 'riyadh');
  await tester.enterText(_field('${S.nameAr} *'), 'فرع الرياض');
  await tester.enterText(_field(S.branchAddress), 'طريق الملك فهد');
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('models', () {
    test('a branch row parses its operational counters', () {
      final branch = AdminBranch.fromRow({
        'id': 'b1',
        'code': 'RUH',
        'name_ar': 'الرياض',
        'name_en': 'Riyadh',
        'address': 'King Fahd road',
        'latitude': 24.7,
        'longitude': 46.6,
        'is_active': true,
        'opens_at': '08:00:00',
        'image_url': 'https://example.com/branch.png',
        'staff_count': '3',
        'zone_count': 2,
        'orders_30d': '17',
        'last_order_at': '2026-10-20T12:30:00Z',
        'created_at': '2026-01-02T09:00:00Z',
      });

      expect(branch.nameEn, 'Riyadh');
      expect(branch.latitude, 24.7);
      expect(branch.longitude, 46.6);
      expect(branch.imageUrl, 'https://example.com/branch.png');
      expect(branch.staffCount, 3);
      expect(branch.zoneCount, 2);
      expect(branch.orders30d, 17);
      expect(branch.lastOrderAt, DateTime.utc(2026, 10, 20, 12, 30));
      expect(branch.hasLocation, isTrue);
      expect(branch.needsSetup, isFalse);
    });

    test('a branch without zones or a location needs setup', () {
      final branch = AdminBranch.fromRow({
        'id': 'b2',
        'code': 'JED',
        'name_ar': 'جدة',
        'name_en': 'Jeddah',
        'address': 'Corniche',
        'zone_count': 0,
      });

      expect(branch.hasLocation, isFalse);
      expect(branch.isActive, isTrue);
      expect(branch.needsSetup, isTrue);
    });

    test('metrics parse string values and compute the active share', () {
      final metrics = AdminBranchMetrics.fromJson({
        'total': '4',
        'active': 3,
        'inactive': '1',
        'without_location': 2,
        'zones_covered': '6',
        'orders_30d': 90,
        'staff_assigned': '5',
      });

      expect(metrics.total, 4);
      expect(metrics.active, 3);
      expect(metrics.inactive, 1);
      expect(metrics.withoutLocation, 2);
      expect(metrics.zonesCovered, 6);
      expect(metrics.orders30d, 90);
      expect(metrics.staffAssigned, 5);
      expect(metrics.activeShare, closeTo(.75, 1e-9));
      expect(AdminBranchMetrics.empty.activeShare, 0);
    });

    test('the draft omits the id when creating and keeps it when editing', () {
      const create = AdminBranchDraft(
        code: 'RUH',
        nameAr: 'الرياض',
        nameEn: 'Riyadh',
        address: 'King Fahd road',
      );
      expect(create.toJson().containsKey('id'), isFalse);
      expect(create.toJson()['opens_at'], isNull);

      final edit = AdminBranchDraft.fromBranch(_branch(1));
      expect(edit.toJson()['id'], 'b1');
      expect(edit.toJson()['name_en'], 'Branch 1');
    });
  });

  group('filterBranches', () {
    final branches = [
      _branch(1),
      _branch(2, isActive: false, withLocation: false, zoneCount: 0),
    ];

    test('matches the code, names, address and phone', () {
      expect(
        filterBranches(branches, search: 'br-2', filter: BranchFilter.all),
        hasLength(1),
      );
      expect(
        filterBranches(
          branches,
          search: 'Address 1',
          filter: BranchFilter.all,
        ).single.id,
        'b1',
      );
      expect(
        filterBranches(
          branches,
          search: '5000002',
          filter: BranchFilter.all,
        ).single.id,
        'b2',
      );
      expect(
        filterBranches(branches, search: '  ', filter: BranchFilter.all),
        hasLength(2),
      );
    });

    test('the status and setup filters are mutually exclusive here', () {
      expect(
        filterBranches(
          branches,
          search: '',
          filter: BranchFilter.active,
        ).single.id,
        'b1',
      );
      expect(
        filterBranches(
          branches,
          search: '',
          filter: BranchFilter.inactive,
        ).single.id,
        'b2',
      );
      expect(
        filterBranches(
          branches,
          search: '',
          filter: BranchFilter.needsSetup,
        ).single.id,
        'b2',
      );
    });
  });

  group('AdminBranchCubit', () {
    test('load fills the branches and their metrics', () async {
      final repository = _FakeBranchRepository(
        branches: [_branch(1), _branch(2, isActive: false)],
        metrics: _metrics,
      );
      final cubit = AdminBranchCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminBranchStatus.ready);
      expect(cubit.state.branches, hasLength(2));
      expect(cubit.state.metrics.orders30d, 128);
      expect(repository.loadCalls, 1);
    });

    test('a metrics failure keeps the branches with empty counters', () async {
      final repository = _FakeBranchRepository(
        branches: [_branch(1)],
        failMetrics: true,
      );
      final cubit = AdminBranchCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminBranchStatus.ready);
      expect(cubit.state.branches, hasLength(1));
      expect(cubit.state.metrics.total, 0);
    });

    test(
      'a successful save reloads the page and a rejected one does not',
      () async {
        final repository = _FakeBranchRepository(branches: [_branch(1)]);
        final cubit = AdminBranchCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();
        expect(repository.loadCalls, 1);

        final outcome = await cubit.saveBranch(
          const AdminBranchDraft(
            code: 'JED',
            nameAr: 'جدة',
            nameEn: 'Jeddah',
            address: 'Corniche',
          ),
        );

        expect(outcome, BranchSaveOutcome.saved);
        expect(repository.loadCalls, 2);

        repository.saveOutcome = BranchSaveOutcome.duplicateCode;
        final rejected = await cubit.saveBranch(
          const AdminBranchDraft(
            code: 'RUH',
            nameAr: 'الرياض',
            nameEn: 'Riyadh',
            address: 'King Fahd road',
          ),
        );

        expect(rejected, BranchSaveOutcome.duplicateCode);
        expect(repository.loadCalls, 2);
      },
    );
  });

  group('branch page', () {
    testWidgets('the wide page shows metrics and the branch table', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpPage(tester, branches: [_branch(1), _branch(2)]);

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminPageFrame), findsOneWidget);
      expect(find.text(S.branches), findsOneWidget);
      expect(find.text(S.branchesMetricTotal), findsOneWidget);
      expect(find.text(S.branchesMetricActive), findsOneWidget);
      expect(find.text(S.branchesMetricOrders), findsOneWidget);
      expect(find.text(S.branchesMetricZones), findsOneWidget);
      expect(find.text(S.branchesTableBranch), findsOneWidget);
      expect(find.text(S.branchesTableContact), findsOneWidget);
      expect(find.text(S.branchesTableOperations), findsOneWidget);
      expect(find.text(S.branchesTableCoverage), findsOneWidget);
      expect(find.text(S.branchesTableStatus), findsOneWidget);
      expect(find.byKey(const Key('branch-add')), findsOneWidget);
      expect(find.byKey(const Key('branch-row-b1')), findsOneWidget);
      expect(find.byKey(const Key('branch-card-b1')), findsNothing);
      expect(find.text('Branch 1'), findsOneWidget);
      expect(
        find.text(
          localizeDigits(S.branchesFilterOption(S.branchesFilterAll, 2)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the narrow page switches to branch cards', (tester) async {
      _setViewport(tester, 420, 900);
      await _pumpPage(tester, branches: [_branch(1)]);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('branch-card-b1')), findsOneWidget);
      expect(find.byKey(const Key('branch-row-b1')), findsNothing);
      expect(find.text(S.branchesTableBranch), findsNothing);
      expect(find.text('Branch 1'), findsOneWidget);
    });

    testWidgets('an empty directory offers to create the first branch', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      await _pumpPage(tester, metrics: AdminBranchMetrics.empty);

      expect(tester.takeException(), isNull);
      expect(find.text(S.noBranchesFound), findsOneWidget);
      expect(find.text(S.branchesEmptyHint), findsOneWidget);
      expect(find.text(S.addBranch), findsNWidgets(2));
    });

    testWidgets('a search without a match offers to clear the filters', (
      tester,
    ) async {
      _setViewport(tester, 1280);
      await _pumpPage(tester, branches: [_branch(1)], search: 'missing');

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchesNoMatches), findsOneWidget);
      expect(find.text(S.clearFilters), findsOneWidget);
      expect(find.text('Branch 1'), findsNothing);
    });

    testWidgets('the setup banner reviews only the branches needing setup', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpPage(
        tester,
        branches: [_branch(1), _branch(2, withLocation: false)],
      );

      expect(find.text(S.branchesNeedsSetupTitle), findsOneWidget);
      expect(
        find.text(localizeDigits(S.branchesNeedsSetupBanner(1))),
        findsOneWidget,
      );

      await tester.tap(find.text(S.branchesSetupAction));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('branch-row-b2')), findsOneWidget);
      expect(find.byKey(const Key('branch-row-b1')), findsNothing);
    });

    testWidgets('a read-only manager sees the hint and no actions', (
      tester,
    ) async {
      _setViewport(tester, 1500);
      await _pumpPage(
        tester,
        branches: [_branch(1)],
        canManage: false,
        canManagePricing: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchesReadOnly), findsOneWidget);
      expect(find.byKey(const Key('branch-add')), findsNothing);
      expect(find.byKey(const Key('branch-menu-b1')), findsNothing);
      expect(find.text('Branch 1'), findsOneWidget);
    });

    testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      _setViewport(tester, 360, 900);
      await _pumpPage(
        tester,
        branches: [_branch(1)],
        direction: TextDirection.rtl,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.branches), findsOneWidget);
      expect(find.text(S.branchesMetricTotal), findsOneWidget);
      expect(find.text('فرع 1'), findsOneWidget);
    });

    testWidgets('the dark wide page fits', (tester) async {
      _setViewport(tester, 1280);
      await _pumpPage(tester, branches: [_branch(1), _branch(2)], dark: true);

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchesTableStatus), findsOneWidget);
      expect(find.byKey(const Key('branch-row-b2')), findsOneWidget);
    });
  });

  group('branch data dialog', () {
    testWidgets('an empty form reports the invalid code', (tester) async {
      _setViewport(tester, 900, 1100);
      await _openBranchDialog(
        tester,
        onSave: (_) async => BranchSaveOutcome.saved,
      );

      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchSaveInvalidCode), findsOneWidget);
      expect(find.byType(BranchDataDialog), findsOneWidget);
    });

    testWidgets('hours that close before opening are rejected', (tester) async {
      _setViewport(tester, 900, 1100);
      await _openBranchDialog(
        tester,
        onSave: (_) async => BranchSaveOutcome.saved,
      );
      await _fillRequiredFields(tester);
      await tester.enterText(_field(S.opensAt), '20:00');
      await tester.enterText(_field(S.closesAt), '08:00');

      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchInvalidHours), findsOneWidget);
      expect(find.byType(BranchDataDialog), findsOneWidget);
    });

    testWidgets('a valid branch is normalised and saved', (tester) async {
      _setViewport(tester, 900, 1100);
      AdminBranchDraft? saved;
      await _openBranchDialog(
        tester,
        onSave: (draft) async {
          saved = draft;
          return BranchSaveOutcome.saved;
        },
      );
      await _fillRequiredFields(tester);
      await tester.enterText(_field(S.opensAt), '08:00');
      await tester.enterText(_field(S.closesAt), '23:00');

      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(saved?.id, isNull);
      expect(saved?.code, 'RIYADH');
      expect(saved?.nameEn, 'فرع الرياض');
      expect(saved?.address, 'طريق الملك فهد');
      expect(saved?.opensAt, '08:00:00');
      expect(saved?.closesAt, '23:00:00');
      expect(find.byType(BranchDataDialog), findsNothing);
    });

    testWidgets('a VAT number must match the ZATCA format', (tester) async {
      _setViewport(tester, 900, 1100);
      AdminBranchDraft? saved;
      await _openBranchDialog(
        tester,
        onSave: (draft) async {
          saved = draft;
          return BranchSaveOutcome.saved;
        },
      );
      await _fillRequiredFields(tester);
      await tester.enterText(_field(S.branchVatNumber), '123');

      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchInvalidVatNumber), findsOneWidget);
      expect(find.byType(BranchDataDialog), findsOneWidget);
      expect(saved, isNull);

      await tester.enterText(
        _field(S.branchVatNumber),
        localizeDigits('310123456789003'),
      );
      await tester.enterText(_field(S.branchLegalName), 'مقهى النخبة للتجارة');
      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(saved?.vatNumber, '310123456789003');
      expect(saved?.legalName, 'مقهى النخبة للتجارة');
      expect(find.byType(BranchDataDialog), findsNothing);
    });

    testWidgets('a duplicate code keeps the dialog open with the reason', (
      tester,
    ) async {
      _setViewport(tester, 900, 1100);
      await _openBranchDialog(
        tester,
        onSave: (_) async => BranchSaveOutcome.duplicateCode,
      );
      await _fillRequiredFields(tester);

      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(S.branchSaveDuplicateCode), findsOneWidget);
      expect(find.byType(BranchDataDialog), findsOneWidget);
    });

    testWidgets('editing keeps the branch identity and fields', (tester) async {
      _setViewport(tester, 900, 1100);
      AdminBranchDraft? saved;
      await _openBranchDialog(
        tester,
        initialBranch: _branch(1),
        onSave: (draft) async {
          saved = draft;
          return BranchSaveOutcome.saved;
        },
      );

      expect(
        tester.widget<TextField>(_field('${S.branchCode} *')).controller?.text,
        'BR-1',
      );
      expect(
        tester.widget<TextField>(_field(S.branchAddress)).controller?.text,
        'Address 1',
      );

      await tester.tap(find.byKey(const Key('branch-data-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(saved?.id, 'b1');
      expect(saved?.code, 'BR-1');
      expect(saved?.latitude, 25.7);
      expect(find.byType(BranchDataDialog), findsNothing);
    });
  });
}

class _FakeBranchRepository extends AdminBranchRepository {
  _FakeBranchRepository({
    this.branches = const <AdminBranch>[],
    this.metrics = AdminBranchMetrics.empty,
    this.failMetrics = false,
  });

  final List<AdminBranch> branches;
  final AdminBranchMetrics metrics;
  final bool failMetrics;
  BranchSaveOutcome saveOutcome = BranchSaveOutcome.saved;
  int loadCalls = 0;

  @override
  Future<List<AdminBranch>> loadBranches() async {
    loadCalls++;
    return branches;
  }

  @override
  Future<AdminBranchMetrics> loadMetrics() async {
    if (failMetrics) throw Exception('metrics unavailable');
    return metrics;
  }

  @override
  Future<BranchSaveOutcome> saveBranch(AdminBranchDraft draft) async {
    return saveOutcome;
  }
}
