import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/data/models/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/data/repositories/admin_kitchen_repository.dart';
import 'package:admin_app/features/kitchen/data/services/kitchen_realtime_feed.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_cubit.dart';
import 'package:admin_app/features/kitchen/presentation/pages/kitchen_page.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';

final DateTime _now = DateTime.utc(2026, 10, 24, 9, 10);

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

AdminKitchenTicketItem _item(
  String id, {
  String nameAr = 'فلات وايت',
  String nameEn = 'Flat white',
  KitchenItemStatus status = KitchenItemStatus.pending,
  String note = '',
  String groupAr = 'الحجم',
  String groupEn = 'Size',
}) => AdminKitchenTicketItem(
  id: id,
  status: status,
  quantity: 1,
  productNameAr: nameAr,
  productNameEn: nameEn,
  note: note,
  optionGroupNameAr: groupAr,
  optionGroupNameEn: groupEn,
  options: const <AdminKitchenOption>[
    AdminKitchenOption(nameAr: 'كبير', nameEn: 'Large'),
  ],
);

AdminKitchenTicket _ticket(
  String id,
  KitchenTicketStatus status, {
  String orderNumber = '#1001',
  String? tableNumber = '7',
  String fulfillmentType = 'dine_in',
  String orderSource = 'pos',
  String customerNote = '',
  String customerName = 'Mona Ali',
  int itemCount = 1,
  int readyCount = 0,
  DateTime? placedAt,
  DateTime? completedAt,
  List<AdminKitchenTicketItem>? items,
}) => AdminKitchenTicket(
  id: id,
  status: status,
  placedAt: placedAt ?? _now.subtract(const Duration(minutes: 4)),
  completedAt: completedAt,
  orderId: 'o-$id',
  orderNumber: orderNumber,
  orderStatus: status.value,
  fulfillmentType: fulfillmentType,
  orderSource: orderSource,
  tableNumber: tableNumber,
  customerNote: customerNote,
  customerName: customerName,
  branchId: 'b1',
  branchCode: 'MAADI',
  branchNameAr: 'المعادي',
  branchNameEn: 'Maadi',
  itemCount: itemCount,
  readyCount: readyCount,
  items: items ?? <AdminKitchenTicketItem>[_item('item-$id')],
);

const _metrics = AdminKitchenMetrics(
  queued: 1,
  preparing: 1,
  ready: 1,
  active: 3,
  completedToday: 2,
  late: 1,
  oldestWaitMinutes: 20,
  avgPrepMinutes: 8,
);

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

class _KitchenHarness extends StatefulWidget {
  const _KitchenHarness({
    required this.tickets,
    required this.metrics,
    required this.now,
    this.hasActiveFilters = false,
    this.canManage = true,
    this.onTicketStatus,
    this.onToggleItem,
    this.onClearFilters,
  });

  final List<AdminKitchenTicket> tickets;
  final AdminKitchenMetrics metrics;
  final DateTime now;
  final bool hasActiveFilters;
  final bool canManage;
  final void Function(AdminKitchenTicket ticket, KitchenTicketStatus status)?
  onTicketStatus;
  final ValueChanged<AdminKitchenTicketItem>? onToggleItem;
  final VoidCallback? onClearFilters;

  @override
  State<_KitchenHarness> createState() => _KitchenHarnessState();
}

class _KitchenHarnessState extends State<_KitchenHarness> {
  final TextEditingController _search = TextEditingController();
  String? _branchId;
  late bool _hasActiveFilters = widget.hasActiveFilters;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _hasActiveFilters || _branchId != null || _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return KitchenPageBody(
      searchController: _search,
      tickets: widget.tickets,
      filters: _filters,
      metrics: widget.metrics,
      now: widget.now,
      branchId: _branchId,
      isRefreshing: false,
      lastUpdatedAt: widget.now,
      busyTicketIds: const <String>{},
      busyItemIds: const <String>{},
      hasActiveFilters: _filtersActive,
      canManage: widget.canManage,
      onSearchChanged: (value) => setState(() {
        _hasActiveFilters = value.trim().isNotEmpty || _branchId != null;
      }),
      onBranchChanged: (value) => setState(() {
        _branchId = value;
        _hasActiveFilters = value != null || _search.text.trim().isNotEmpty;
      }),
      onClearFilters: () {
        widget.onClearFilters?.call();
        _search.clear();
        setState(() {
          _branchId = null;
          _hasActiveFilters = false;
        });
      },
      onRefresh: () {},
      onTicketStatus: (ticket, status) =>
          widget.onTicketStatus?.call(ticket, status),
      onToggleItem: (item) => widget.onToggleItem?.call(item),
    );
  }
}

class _PageRepository extends AdminKitchenRepository {
  List<AdminKitchenTicket> tickets = <AdminKitchenTicket>[];

  bool failBoard = false;
  int boardCalls = 0;
  KitchenMutationOutcome outcome = KitchenMutationOutcome.success;
  KitchenTicketStatus? lastStatus;
  KitchenItemStatus? lastItemStatus;

  @override
  Future<AdminKitchenBoard> loadBoard({
    String? search,
    String? branchId,
    int limit = 150,
  }) async {
    boardCalls += 1;
    if (failBoard) throw StateError('board failed');
    return AdminKitchenBoard(tickets: tickets, total: tickets.length);
  }

  @override
  Future<AdminKitchenMetrics> loadMetrics({String? branchId}) async => _metrics;

  @override
  Future<AdminKitchenFilters> loadFilters() async => _filters;

  @override
  Future<KitchenMutationOutcome> setTicketStatus(
    String ticketId,
    KitchenTicketStatus status,
  ) async {
    lastStatus = status;
    return outcome;
  }

  @override
  Future<KitchenMutationOutcome> setItemStatus(
    String itemId,
    KitchenItemStatus status,
  ) async {
    lastItemStatus = status;
    return outcome;
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('kitchen board', () {
    testWidgets('the wide board shows four columns and every ticket action', (
      tester,
    ) async {
      _setViewport(tester, 1500, 1150);
      final tickets = <AdminKitchenTicket>[
        _ticket(
          't1',
          KitchenTicketStatus.queued,
          orderNumber: '#1001',
          customerNote: 'Extra hot please',
          placedAt: _now.subtract(const Duration(minutes: 20)),
        ),
        _ticket('t2', KitchenTicketStatus.preparing, orderNumber: '#1002'),
        _ticket(
          't3',
          KitchenTicketStatus.ready,
          orderNumber: '#1003',
          readyCount: 1,
        ),
        _ticket(
          't4',
          KitchenTicketStatus.completed,
          orderNumber: '#1004',
          readyCount: 1,
          completedAt: DateTime.utc(2026, 10, 24, 9, 5),
        ),
      ];
      AdminKitchenTicket? tappedTicket;
      KitchenTicketStatus? tappedStatus;
      AdminKitchenTicketItem? toggledItem;

      await _pump(
        tester,
        _KitchenHarness(
          tickets: tickets,
          metrics: _metrics,
          now: _now,
          onTicketStatus: (ticket, status) {
            tappedTicket = ticket;
            tappedStatus = status;
          },
          onToggleItem: (item) => toggledItem = item,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.kitchen), findsOneWidget);
      expect(find.text(S.kitchenSubtitle), findsOneWidget);
      expect(find.text(S.kitchenLive), findsOneWidget);
      expect(find.text(S.kitchenCompletedTodayValue(2)), findsOneWidget);

      expect(find.text(S.kitchenMetricQueued), findsOneWidget);
      expect(find.text(S.kitchenMetricLate), findsNWidgets(2));
      expect(find.text(S.kitchenColumnQueued), findsOneWidget);
      expect(find.text(S.kitchenColumnPreparing), findsNWidgets(2));
      expect(find.text(S.kitchenColumnReady), findsNWidgets(2));
      expect(find.text(S.kitchenColumnCompleted), findsOneWidget);

      expect(find.text('#1001'), findsOneWidget);
      expect(find.text('#1002'), findsOneWidget);
      expect(find.text('#1003'), findsOneWidget);
      expect(find.text('#1004'), findsOneWidget);
      expect(find.text(S.kitchenCustomerNote), findsOneWidget);
      expect(find.text('Extra hot please'), findsOneWidget);
      expect(find.text('Dine in · Table 7'), findsWidgets);

      expect(find.byKey(const Key('kitchen-start-t1')), findsOneWidget);
      expect(find.byKey(const Key('kitchen-ready-t2')), findsOneWidget);
      expect(find.byKey(const Key('kitchen-complete-t3')), findsOneWidget);
      expect(find.byKey(const Key('kitchen-recall-t3')), findsOneWidget);
      expect(find.byKey(const Key('kitchen-recall-t4')), findsOneWidget);

      await tester.tap(find.byKey(const Key('kitchen-item-toggle-item-t1')));
      await tester.pump();
      expect(toggledItem?.id, 'item-t1');

      await tester.tap(find.byKey(const Key('kitchen-start-t1')));
      await tester.pump();
      expect(tappedTicket?.id, 't1');
      expect(tappedStatus, KitchenTicketStatus.preparing);
    });

    testWidgets('the narrow board opens the first column that has work', (
      tester,
    ) async {
      _setViewport(tester, 800, 1000);
      final tickets = <AdminKitchenTicket>[
        _ticket(
          'preparing',
          KitchenTicketStatus.preparing,
          orderNumber: '#2001',
        ),
      ];

      await _pump(
        tester,
        _KitchenHarness(tickets: tickets, metrics: _metrics, now: _now),
      );

      expect(tester.takeException(), isNull);
      for (final status in KitchenTicketStatus.values.where(
        (status) => status != KitchenTicketStatus.cancelled,
      )) {
        expect(find.byKey(Key('kitchen-tab-${status.value}')), findsOneWidget);
      }
      expect(find.text('#2001'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kitchen-tab-queued')));
      await tester.pump();

      expect(find.text('#2001'), findsNothing);
      expect(find.text(S.kitchenEmptyColumn), findsOneWidget);

      await tester.tap(find.byKey(const Key('kitchen-tab-preparing')));
      await tester.pump();

      expect(find.text('#2001'), findsOneWidget);
    });

    testWidgets('an empty kitchen explains that new orders arrive live', (
      tester,
    ) async {
      _setViewport(tester, 1500, 1000);

      await _pump(
        tester,
        _KitchenHarness(
          tickets: const <AdminKitchenTicket>[],
          metrics: AdminKitchenMetrics.empty,
          now: _now,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.kitchenEmptyTitle), findsOneWidget);
      expect(find.text(S.kitchenEmptyHint), findsOneWidget);
      expect(find.text(S.kitchenNoMatches), findsNothing);
      expect(find.text(S.kitchenColumnQueued), findsNothing);
    });

    testWidgets('a filtered empty board offers to clear the filters', (
      tester,
    ) async {
      _setViewport(tester, 1500, 1000);
      var cleared = false;

      await _pump(
        tester,
        _KitchenHarness(
          tickets: const <AdminKitchenTicket>[],
          metrics: AdminKitchenMetrics.empty,
          now: _now,
          hasActiveFilters: true,
          onClearFilters: () => cleared = true,
        ),
      );

      expect(find.text(S.kitchenNoMatches), findsOneWidget);
      expect(find.text(S.kitchenNoMatchesHint), findsOneWidget);

      await tester.tap(find.text(S.clearFilters));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(find.text(S.kitchenEmptyTitle), findsOneWidget);
      expect(find.text(S.kitchenNoMatches), findsNothing);
    });

    testWidgets('a read-only member sees the board without actions', (
      tester,
    ) async {
      _setViewport(tester, 1500, 1000);

      await _pump(
        tester,
        _KitchenHarness(
          tickets: <AdminKitchenTicket>[
            _ticket('t1', KitchenTicketStatus.queued),
          ],
          metrics: _metrics,
          now: _now,
          canManage: false,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.kitchenReadOnly), findsOneWidget);
      expect(find.byKey(const Key('kitchen-start-t1')), findsNothing);
      expect(
        find.byKey(const Key('kitchen-item-toggle-item-t1')),
        findsNothing,
      );
    });

    testWidgets('the board renders Arabic RTL in dark mode', (tester) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      _setViewport(tester, 1500, 1150);

      await _pump(
        tester,
        _KitchenHarness(
          tickets: <AdminKitchenTicket>[
            _ticket(
              't1',
              KitchenTicketStatus.queued,
              placedAt: _now.subtract(const Duration(minutes: 20)),
            ),
          ],
          metrics: _metrics,
          now: _now,
        ),
        dark: true,
        direction: TextDirection.rtl,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.kitchen), findsOneWidget);
      expect(find.text(S.kitchenColumnQueued), findsOneWidget);
      expect(find.text('فلات وايت'), findsOneWidget);
      expect(find.text(S.kitchenMetricLate), findsOneWidget);
      expect(find.text(S.kitchenLate), findsOneWidget);
    });
  });

  group('kitchen page', () {
    testWidgets('a started ticket confirms with a snackbar', (tester) async {
      _setViewport(tester, 1500, 1150);
      final repository = _PageRepository()
        ..tickets = <AdminKitchenTicket>[
          _ticket('t1', KitchenTicketStatus.queued),
        ];
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: KitchenRealtimeFeed(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final search = AdminSearchController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: Scaffold(
            body: KitchenPage(
              searchController: search,
              cubit: cubit,
              canManage: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kitchen-start-t1')));
      await tester.pumpAndSettle();

      expect(find.text(S.kitchenTicketStarted), findsOneWidget);
      expect(repository.lastStatus, KitchenTicketStatus.preparing);
      expect(repository.boardCalls, 2);
    });

    testWidgets('a rejected action tells the kitchen why', (tester) async {
      _setViewport(tester, 1500, 1150);
      final repository = _PageRepository()
        ..tickets = <AdminKitchenTicket>[
          _ticket('t1', KitchenTicketStatus.queued),
        ]
        ..outcome = KitchenMutationOutcome.permissionDenied;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: KitchenRealtimeFeed(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: Scaffold(
            body: KitchenPage(
              searchController: AdminSearchController(),
              cubit: cubit,
              canManage: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kitchen-start-t1')));
      await tester.pumpAndSettle();

      expect(find.text(S.kitchenPermissionDenied), findsOneWidget);
      expect(repository.boardCalls, 1);
    });

    testWidgets('a failed first load retries from the failure view', (
      tester,
    ) async {
      _setViewport(tester, 1500, 1150);
      final repository = _PageRepository()..failBoard = true;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: KitchenRealtimeFeed(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeClass.light(),
          home: Scaffold(
            body: KitchenPage(
              searchController: AdminSearchController(),
              cubit: cubit,
              canManage: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('board failed'), findsOneWidget);
      expect(find.text(S.retry), findsOneWidget);
      expect(find.text(S.kitchenColumnQueued), findsNothing);

      repository
        ..failBoard = false
        ..tickets = <AdminKitchenTicket>[
          _ticket('t1', KitchenTicketStatus.queued),
        ];
      await tester.tap(find.text(S.retry));
      await tester.pumpAndSettle();

      expect(find.text(S.kitchen), findsOneWidget);
      expect(find.text('#1001'), findsOneWidget);
      expect(find.textContaining('board failed'), findsNothing);
    });
  });
}
