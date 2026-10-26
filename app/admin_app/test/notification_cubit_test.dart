import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_cubit.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_state.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';

AdminNotification _notification(String id) => AdminNotification(
  id: id,
  type: AdminNotificationType.promo,
  customer: AdminNotificationCustomer(id: 'u-$id', fullName: 'Customer $id'),
  push: const AdminNotificationPush(state: AdminNotificationPushState.sent),
  titleEn: 'Title $id',
  bodyEn: 'Body $id',
  createdAt: DateTime.utc(2026, 10, 1, 9, 30),
);

class _FakeNotificationsRepository extends AdminNotificationsRepository {
  _FakeNotificationsRepository();

  List<AdminNotification> rows = const <AdminNotification>[];
  int total = 0;
  AdminNotificationMetrics metrics = AdminNotificationMetrics.empty;
  AdminPushHealth health = const AdminPushHealth();
  bool failRows = false;
  bool failMetrics = false;

  int loadCalls = 0;
  int metricsCalls = 0;
  int healthCalls = 0;
  String? lastSearch;
  String? lastType;
  bool? lastRead;
  String? lastPush;
  int? lastPage;
  int? lastPageSize;

  AdminSendResult sendResult = const AdminSendResult(
    ok: true,
    recipients: 3,
    pushReady: 2,
  );
  AdminResendResult resendResult = const AdminResendResult(
    ok: true,
    queued: true,
  );
  NotificationMutationOutcome mutation = NotificationMutationOutcome.success;
  AdminNotificationDraft? sentDraft;
  String? resentId;
  String? lastReadId;
  bool? lastReadValue;
  String? deletedId;

  @override
  Future<AdminNotificationPage> loadNotifications({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    int page = 0,
    int pageSize = 10,
  }) async {
    loadCalls += 1;
    lastSearch = search;
    lastType = type?.value;
    lastRead = isRead;
    lastPush = pushState;
    lastPage = page;
    lastPageSize = pageSize;
    if (failRows) throw StateError('rows failed');
    return AdminNotificationPage(total: total, rows: rows);
  }

  @override
  Future<AdminNotificationMetrics> loadMetrics() async {
    metricsCalls += 1;
    if (failMetrics) throw StateError('metrics failed');
    return metrics;
  }

  @override
  Future<AdminPushHealth> loadPushHealth() async {
    healthCalls += 1;
    return health;
  }

  @override
  Future<AdminSendResult> sendNotification({
    required AdminNotificationType type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required AdminNotificationAudience audience,
    String? customerId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    sentDraft = AdminNotificationDraft(
      type: type,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
      audience: audience,
      customerId: customerId,
      payload: payload,
    );
    return sendResult;
  }

  @override
  Future<AdminResendResult> resendNotification(String notificationId) async {
    resentId = notificationId;
    return resendResult;
  }

  @override
  Future<NotificationMutationOutcome> setRead(
    String notificationId,
    bool read,
  ) async {
    lastReadId = notificationId;
    lastReadValue = read;
    return mutation;
  }

  @override
  Future<NotificationMutationOutcome> deleteNotification(
    String notificationId,
  ) async {
    deletedId = notificationId;
    if (mutation == NotificationMutationOutcome.success) {
      rows = rows.where((row) => row.id != notificationId).toList();
      total = rows.length;
    }
    return mutation;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  test(
    'the cubit loads the rows with the metrics and the push health',
    () async {
      final repository = _FakeNotificationsRepository()
        ..rows = [_notification('n1'), _notification('n2')]
        ..total = 12
        ..metrics = const AdminNotificationMetrics(total: 12, unread: 2)
        ..health = const AdminPushHealth(vaultAvailable: true);
      final cubit = AdminNotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AdminNotificationsPageStatus.ready);
      expect(cubit.state.notifications.map((row) => row.id), ['n1', 'n2']);
      expect(cubit.state.total, 12);
      expect(cubit.state.pages, 2);
      expect(cubit.state.metrics.total, 12);
      expect(cubit.state.pushHealth.vaultAvailable, isTrue);
      expect(repository.loadCalls, 1);
      expect(repository.metricsCalls, 1);
      expect(repository.healthCalls, 1);
      expect(repository.lastPage, 0);
      expect(repository.lastPageSize, 10);
      expect(repository.lastSearch, '');
      expect(repository.lastType, isNull);
      expect(repository.lastRead, isNull);
      expect(repository.lastPush, isNull);
    },
  );

  test('the filters reset the page and reach the server', () async {
    final repository = _FakeNotificationsRepository()..total = 30;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    cubit.setPage(2);
    await _settle();
    expect(cubit.state.page, 2);

    cubit.setType(NotificationTypeFilter.promo);
    await _settle();
    expect(cubit.state.type, NotificationTypeFilter.promo);
    expect(cubit.state.page, 0);
    expect(repository.lastType, 'promo');
    expect(cubit.state.isRefreshingRows, isFalse);

    cubit.setReadFilter(NotificationReadFilter.unread);
    await _settle();
    expect(cubit.state.readFilter, NotificationReadFilter.unread);
    expect(repository.lastRead, isFalse);

    cubit.setPushFilter(NotificationPushFilter.failed);
    await _settle();
    expect(cubit.state.pushFilter, NotificationPushFilter.failed);
    expect(repository.lastPush, 'failed');

    cubit.clearFilters();
    await _settle();
    expect(cubit.state.hasActiveFilters, isFalse);
    expect(repository.lastType, isNull);
    expect(repository.lastRead, isNull);
    expect(repository.lastPush, isNull);
  });

  test(
    'typing searches after a pause and clearing it refreshes at once',
    () async {
      final repository = _FakeNotificationsRepository();
      final cubit = AdminNotificationsCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();

      final callsAfterLoad = repository.loadCalls;
      cubit.updateSearch('mona');
      expect(cubit.state.search, 'mona');
      expect(cubit.state.page, 0);
      expect(repository.loadCalls, callsAfterLoad);
      expect(repository.lastSearch, '');

      cubit.updateSearch('');
      await _settle();

      expect(cubit.state.search, '');
      expect(repository.loadCalls, callsAfterLoad + 1);
      expect(repository.lastSearch, '');
    },
  );

  test('the page is clamped to the available server pages', () async {
    final repository = _FakeNotificationsRepository()
      ..rows = [
        for (var index = 0; index < 10; index++) _notification('n$index'),
      ]
      ..total = 25;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    expect(cubit.state.pages, 3);
    cubit.setPage(1);
    await _settle();
    expect(cubit.state.page, 1);
    expect(repository.lastPage, 1);

    cubit.setPage(9);
    await _settle();
    expect(cubit.state.page, 2);
    expect(repository.lastPage, 2);
  });

  test('read, resend and delete mutations refresh the directory', () async {
    final repository = _FakeNotificationsRepository()
      ..rows = [_notification('n1'), _notification('n2')]
      ..total = 2;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    final read = await cubit.setRead('n1', true);
    expect(read, NotificationMutationOutcome.success);
    expect(repository.lastReadId, 'n1');
    expect(repository.lastReadValue, isTrue);
    expect(repository.loadCalls, 2);

    final resend = await cubit.resend('n2');
    expect(resend.queued, isTrue);
    expect(repository.resentId, 'n2');
    expect(repository.loadCalls, 3);

    final deleted = await cubit.delete('n1');
    expect(deleted, NotificationMutationOutcome.success);
    expect(repository.deletedId, 'n1');
    expect(repository.loadCalls, 4);
    expect(cubit.state.notifications.map((row) => row.id), ['n2']);
    expect(cubit.state.total, 1);
  });

  test('a successful send resets the page and refreshes the summary', () async {
    final repository = _FakeNotificationsRepository()
      ..total = 4
      ..metrics = const AdminNotificationMetrics(total: 4);
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setPage(2);
    await _settle();

    final result = await cubit.send(
      const AdminNotificationDraft(
        type: AdminNotificationType.loyalty,
        titleAr: 'هدية',
        titleEn: 'A gift',
        bodyAr: 'لك نقاط إضافية',
        bodyEn: 'Extra points for you',
        audience: AdminNotificationAudience.pushEnabled,
        payload: {'screen': 'loyalty'},
      ),
    );

    expect(result.ok, isTrue);
    expect(result.recipients, 3);
    expect(repository.sentDraft?.type, AdminNotificationType.loyalty);
    expect(
      repository.sentDraft?.audience,
      AdminNotificationAudience.pushEnabled,
    );
    expect(repository.sentDraft?.payload['screen'], 'loyalty');
    expect(cubit.state.page, 0);
    expect(repository.loadCalls, 2);
    expect(repository.metricsCalls, 2);
  });

  test('the rows still load when the summary requests fail', () async {
    final repository = _FakeNotificationsRepository()
      ..rows = [_notification('n1')]
      ..total = 1
      ..failMetrics = true;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminNotificationsPageStatus.ready);
    expect(cubit.state.notifications, hasLength(1));
    expect(cubit.state.metrics.total, 0);
  });

  test('a failing rows request becomes a failure state', () async {
    final repository = _FakeNotificationsRepository()..failRows = true;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminNotificationsPageStatus.failure);
    expect(cubit.state.errorMessage, isNotNull);
    expect(cubit.state.notifications, isEmpty);
  });
}
