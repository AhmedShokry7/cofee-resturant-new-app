import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_directory.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

const _metrics = AdminNotificationMetrics(
  total: 25,
  unread: 4,
  today: 2,
  adminSent: 9,
  campaigns: 3,
  customersTotal: 40,
  pushEnabledCustomers: 20,
  reachableCustomers: 18,
  devicesTotal: 22,
  pushSent: 18,
  pushFailed: 2,
  pushSuccessRate: 92.4,
  byType: <AdminNotificationType, int>{
    AdminNotificationType.orderStatus: 14,
    AdminNotificationType.promo: 5,
    AdminNotificationType.system: 2,
    AdminNotificationType.loyalty: 3,
    AdminNotificationType.subscription: 1,
  },
);

const _readyHealth = AdminPushHealth(
  vaultAvailable: true,
  webhookSecretConfigured: true,
  pgNetInstalled: true,
  dispatchTriggerInstalled: true,
  functionUrl: 'https://example.supabase.co/functions/v1/send-push',
  functionUrlConfigured: true,
  devicesTotal: 22,
  devicesAndroid: 12,
  devicesIos: 10,
  devicesWithLocale: 20,
  customersTotal: 40,
  pushEnabledCustomers: 20,
  reachableCustomers: 18,
  delivered30d: 90,
  failed30d: 4,
  skipped30d: 2,
  invalidToken30d: 1,
  lastWebhookStatus: 200,
  lastSuccessAt: null,
);

const _brokenHealth = AdminPushHealth(
  vaultAvailable: true,
  webhookSecretConfigured: false,
  pgNetInstalled: true,
  dispatchTriggerInstalled: false,
  functionUrlConfigured: true,
  reachableCustomers: 0,
);

AdminNotification _notification(
  int index, {
  bool isRead = false,
  AdminNotificationType type = AdminNotificationType.promo,
  AdminNotificationPushState pushState = AdminNotificationPushState.sent,
  bool campaign = true,
}) => AdminNotification(
  id: 'n$index',
  type: type,
  customer: AdminNotificationCustomer(
    id: 'u$index',
    fullName: 'Customer $index',
    email: 'customer$index@example.com',
  ),
  push: AdminNotificationPush(
    state: pushState,
    total: 1,
    sent: pushState == AdminNotificationPushState.sent ? 1 : 0,
    failed: pushState == AdminNotificationPushState.failed ? 1 : 0,
  ),
  titleAr: 'إشعار $index',
  titleEn: 'Notification $index',
  bodyAr: 'تفاصيل الإشعار $index',
  bodyEn: 'Details for notification $index',
  isRead: isRead,
  createdAt: DateTime.utc(2026, 10, index, 9, 30),
  campaign: campaign
      ? const AdminNotificationCampaign(
          id: 'c1',
          audience: AdminNotificationAudience.all,
          recipientCount: 12,
        )
      : null,
);

void _setViewport(WidgetTester tester, double width, [double height = 1100]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  List<AdminNotification> notifications = const <AdminNotification>[],
  AdminNotificationMetrics metrics = _metrics,
  AdminPushHealth health = _readyHealth,
  int? total,
  int pageSize = 10,
  String search = '',
  bool canSend = true,
  bool canManage = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: _PageHarness(
          notifications: notifications,
          metrics: metrics,
          health: health,
          total: total ?? notifications.length,
          pageSize: pageSize,
          search: search,
          canSend: canSend,
          canManage: canManage,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _PageHarness extends StatefulWidget {
  const _PageHarness({
    required this.notifications,
    required this.metrics,
    required this.health,
    required this.total,
    required this.pageSize,
    required this.search,
    required this.canSend,
    required this.canManage,
  });

  final List<AdminNotification> notifications;
  final AdminNotificationMetrics metrics;
  final AdminPushHealth health;
  final int total;
  final int pageSize;
  final String search;
  final bool canSend;
  final bool canManage;

  @override
  State<_PageHarness> createState() => _PageHarnessState();
}

class _PageHarnessState extends State<_PageHarness> {
  int _page = 0;

  int get _pages => widget.total <= 0
      ? 0
      : (widget.total + widget.pageSize - 1) ~/ widget.pageSize;

  List<AdminNotification> get _rows {
    final start = (_page * widget.pageSize).clamp(
      0,
      widget.notifications.length,
    );
    final end = (start + widget.pageSize).clamp(0, widget.notifications.length);
    return widget.notifications.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationPageBody(
      metrics: widget.metrics,
      health: widget.health,
      canSend: widget.canSend,
      canManage: widget.canManage,
      onCompose: () {},
      onRecheck: () {},
      onSetup: () {},
      directory: NotificationDirectory(
        notifications: _rows,
        total: widget.total,
        page: _page,
        pages: _pages,
        pageSize: widget.pageSize,
        search: widget.search,
        type: NotificationTypeFilter.all,
        readFilter: NotificationReadFilter.all,
        pushFilter: NotificationPushFilter.all,
        isRefreshingRows: false,
        canSend: widget.canSend,
        canManage: widget.canManage,
        onSearchChanged: (_) {},
        onTypeChanged: (_) {},
        onReadChanged: (_) {},
        onPushChanged: (_) {},
        onClearFilters: () {},
        onPageChanged: (page) => setState(() => _page = page),
        onOpen: (_) {},
        onAction: (_, _) {},
      ),
    );
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the wide page shows the metrics, push health and table', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      notifications: [
        _notification(1),
        _notification(
          2,
          isRead: true,
          type: AdminNotificationType.orderStatus,
          pushState: AdminNotificationPushState.failed,
          campaign: false,
        ),
      ],
      pageSize: 10,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminPageFrame), findsOneWidget);
    expect(find.text(S.notifications), findsOneWidget);
    expect(find.text(S.notificationsDescription), findsOneWidget);
    expect(find.byKey(const Key('notification-compose-open')), findsOneWidget);

    expect(find.text(S.notificationsMetricTotal), findsOneWidget);
    expect(find.text(S.notificationsMetricUnread), findsNWidgets(2));
    expect(find.text(S.notificationsMetricAdminSent), findsOneWidget);
    expect(find.text(S.notificationsMetricPushRate), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('92.4%'), findsOneWidget);

    expect(find.text(S.notificationsPushHealthTitle), findsOneWidget);
    expect(find.text(S.notificationsPushHealthy), findsOneWidget);
    expect(
      find.byKey(const Key('notification-health-recheck')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notification-health-setup')), findsOneWidget);

    expect(find.text(S.notificationsTableNotification), findsOneWidget);
    expect(find.text(S.notificationsTableCustomer), findsOneWidget);
    expect(find.text(S.notificationsTableType), findsOneWidget);
    expect(find.text(S.notificationsTableSource), findsOneWidget);
    expect(find.text(S.notificationsTableDate), findsOneWidget);
    expect(find.text(S.notificationsTableRead), findsNWidgets(2));
    expect(find.text(S.notificationsTablePush), findsOneWidget);

    expect(find.byKey(const Key('notification-row-n1')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-n2')), findsOneWidget);
    expect(find.byKey(const Key('notification-card-n1')), findsNothing);
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.text('Details for notification 1'), findsOneWidget);
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text(S.notificationsSourceCampaign), findsOneWidget);
    expect(find.text(S.notificationsSourceAutomatic), findsOneWidget);
    expect(find.text(S.notificationsUnread), findsNWidgets(2));
    expect(find.text(S.notificationsRead), findsNWidgets(2));
    expect(find.text(S.notificationsPushSent), findsOneWidget);
    expect(find.text(S.notificationsPushFailed), findsOneWidget);
    expect(find.text(S.notificationsRowsLabel(1, 2, 2)), findsOneWidget);
  });

  testWidgets('the narrow page switches to notification cards', (tester) async {
    _setViewport(tester, 420, 900);
    await _pumpPage(
      tester,
      notifications: [_notification(1), _notification(2, isRead: true)],
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('notification-card-n1')), findsOneWidget);
    expect(find.byKey(const Key('notification-card-n2')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-n1')), findsNothing);
    expect(find.text(S.notificationsTableNotification), findsNothing);
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.text(S.notificationsMetricTotal), findsOneWidget);
  });

  testWidgets('an empty directory explains where notifications come from', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, metrics: AdminNotificationMetrics.empty);

    expect(tester.takeException(), isNull);
    expect(find.text(S.notificationsEmpty), findsOneWidget);
    expect(find.text(S.notificationsEmptyHint), findsOneWidget);
    expect(find.text(S.notificationsNoMatches), findsNothing);
  });

  testWidgets('a search without a match offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, search: 'missing');

    expect(tester.takeException(), isNull);
    expect(find.text(S.notificationsNoMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);
    expect(find.text('Notification 1'), findsNothing);
  });

  testWidgets('the directory paginates through the server pages', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      notifications: [
        for (var index = 1; index <= 7; index++) _notification(index),
      ],
      pageSize: 5,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('notification-row-n1')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-n6')), findsNothing);
    expect(find.text(S.notificationsRowsLabel(1, 5, 7)), findsOneWidget);

    await tester.tap(find.byTooltip(S.nextPage));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-row-n6')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-n7')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-n1')), findsNothing);
    expect(find.text(S.notificationsRowsLabel(6, 7, 7)), findsOneWidget);
  });

  testWidgets('a read-only manager sees the hint and only details', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      notifications: [_notification(1)],
      canSend: false,
      canManage: false,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.notificationsReadOnly), findsOneWidget);
    expect(find.byKey(const Key('notification-compose-open')), findsNothing);
    expect(find.text('Notification 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-menu-n1')));
    await tester.pumpAndSettle();

    expect(find.text(S.notificationsViewDetails), findsOneWidget);
    expect(find.text(S.notificationsDelete), findsNothing);
    expect(find.text(S.notificationsResend), findsNothing);
    expect(find.text(S.notificationsMarkRead), findsNothing);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      notifications: [_notification(1), _notification(2, isRead: true)],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.notifications), findsOneWidget);
    expect(find.text(S.notificationsMetricTotal), findsOneWidget);
    expect(find.text('إشعار 1'), findsOneWidget);
    expect(find.text('Customer 1'), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      notifications: [_notification(1), _notification(2)],
      dark: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('notification-row-n2')), findsOneWidget);
    expect(find.text(S.notificationsPushHealthTitle), findsOneWidget);
  });

  testWidgets('an incomplete push setup lists what is missing', (tester) async {
    _setViewport(tester, 1400);
    await _pumpPage(
      tester,
      metrics: AdminNotificationMetrics.empty,
      health: _brokenHealth,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.notificationsPushError), findsOneWidget);
    expect(find.text(S.notificationsPushCheckMissing), findsWidgets);
    expect(find.text(S.notificationsPushSecretHint), findsOneWidget);
    expect(find.byKey(const Key('notification-health-setup')), findsOneWidget);
    expect(find.text(S.notificationsPushHealthy), findsNothing);
  });
}
