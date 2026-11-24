import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_bulk_bar.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_directory.dart';

AdminNotification _notification(String id, {bool summary = false}) =>
    AdminNotification(
      id: id,
      type: AdminNotificationType.promo,
      customer: AdminNotificationCustomer(
        id: 'u-$id',
        fullName: 'Customer $id',
      ),
      push: const AdminNotificationPush(state: AdminNotificationPushState.sent),
      titleEn: 'Title $id',
      bodyEn: 'Body $id',
      createdAt: DateTime.utc(2026, 10, 1, 9, 30),
      campaign: summary
          ? const AdminNotificationCampaign(id: 'c1', isSummary: true)
          : null,
    );

class _Harness extends StatefulWidget {
  const _Harness({required this.notifications, this.canManage = true});

  final List<AdminNotification> notifications;
  final bool canManage;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final Set<String> selected = <String>{};
  bool allMatching = false;
  bool busy = false;
  int deletePresses = 0;

  void _toggle(String id) => setState(() {
    if (!selected.remove(id)) selected.add(id);
    allMatching = false;
  });

  void _togglePage(bool value) => setState(() {
    final deletable = widget.notifications
        .where((n) => !n.isCampaignSummary)
        .map((n) => n.id);
    if (value) {
      selected.addAll(deletable);
    } else {
      selected.removeAll(deletable);
    }
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: NotificationDirectory(
            notifications: widget.notifications,
            total: widget.notifications.length,
            page: 0,
            pages: 1,
            pageSize: 10,
            search: '',
            type: NotificationTypeFilter.all,
            readFilter: NotificationReadFilter.all,
            pushFilter: NotificationPushFilter.all,
            campaignFilter: NotificationCampaignFilter.all,
            dateFrom: null,
            dateTo: null,
            isRefreshingRows: false,
            canSend: true,
            canManage: widget.canManage,
            onSearchChanged: (_) {},
            onTypeChanged: (_) {},
            onReadChanged: (_) {},
            onPushChanged: (_) {},
            onCampaignChanged: (_) {},
            onDateChanged: (_, _) {},
            onClearFilters: () {},
            onPageChanged: (_) {},
            onOpen: (_) {},
            onAction: (_, _) {},
            selectedIds: selected,
            selectedAllMatching: allMatching,
            isBulkBusy: busy,
            onToggleSelection: _toggle,
            onTogglePageSelection: _togglePage,
            onSelectAllMatching: () => setState(() {
              selected
                ..clear()
                ..addAll(widget.notifications.map((n) => n.id));
              allMatching = true;
            }),
            onClearSelection: () => setState(() {
              selected.clear();
              allMatching = false;
            }),
            onBulkDelete: () => setState(() => deletePresses++),
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  tester.view.physicalSize = const Size(1500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(harness);
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('bulk bar shows count, scope, clear and delete', (tester) async {
    await _pump(
      tester,
      _Harness(notifications: [_notification('n1'), _notification('n2')]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('notification-bulk-bar')), findsOneWidget);
    expect(find.byKey(const Key('notification-select-page')), findsOneWidget);
    expect(
      find.byKey(const Key('notification-select-all-matching')),
      findsOneWidget,
    );
    expect(find.text(S.notificationsSelectPage), findsOneWidget);
    expect(find.text(S.notificationsBulkScopePage), findsOneWidget);
    expect(find.text(S.notificationsClearSelection), findsOneWidget);
    expect(find.text(S.notificationsBulkDelete), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-select-n1')));
    await tester.pump();
    expect(find.text(S.notificationsBulkSelectedCount(1)), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-select-all-matching')));
    await tester.pump();
    expect(
      find.textContaining(S.notificationsBulkScopeAllMatching),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('notification-clear-selection')));
    await tester.pump();
    expect(find.text(S.notificationsBulkScopePage), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-select-page')));
    await tester.pump();
    expect(find.text(S.notificationsBulkSelectedCount(2)), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-bulk-delete')));
    await tester.pump();
    expect(find.text(S.notificationsBulkDeleteTitle), findsNothing);
  });

  testWidgets('campaign summary rows have no checkbox', (tester) async {
    await _pump(
      tester,
      _Harness(
        notifications: [
          _notification('n1'),
          _notification('s1', summary: true),
        ],
      ),
    );
    expect(find.byKey(const Key('notification-select-n1')), findsOneWidget);
    expect(find.byKey(const Key('notification-select-s1')), findsNothing);
  });

  testWidgets('read-only managers see no bulk bar', (tester) async {
    await _pump(
      tester,
      _Harness(notifications: [_notification('n1')], canManage: false),
    );
    expect(find.byKey(const Key('notification-bulk-bar')), findsNothing);
    expect(find.byKey(const Key('notification-select-n1')), findsNothing);
  });

  testWidgets('bulk delete confirmation dialog explains the scope', (
    tester,
  ) async {
    await _pump(tester, _Harness(notifications: [_notification('n1')]));
    unawaited(
      showNotificationBulkDeleteDialog(
        tester.element(find.byKey(const Key('notification-bulk-bar'))),
        count: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.notificationsBulkDeleteTitle), findsOneWidget);
    expect(find.text(S.notificationsBulkDeleteMessage(1)), findsOneWidget);
    expect(
      find.byKey(const Key('notification-bulk-delete-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('notification-bulk-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(S.notificationsBulkDeleteTitle), findsNothing);
  });
}
