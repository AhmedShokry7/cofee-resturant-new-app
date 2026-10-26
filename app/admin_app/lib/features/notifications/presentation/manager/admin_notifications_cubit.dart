import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/data/models/admin_push_health.dart';
import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_state.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';

class AdminNotificationsCubit extends Cubit<AdminNotificationsState> {
  AdminNotificationsCubit({AdminNotificationsRepository? repository})
    : _repository = repository ?? AdminNotificationsRepository(),
      super(const AdminNotificationsState());

  final AdminNotificationsRepository _repository;
  Timer? _searchTimer;
  int _requestId = 0;

  Future<void> load() async {
    if (state.isLoading) return;
    await _fetch(withSummary: true, first: true);
  }

  Future<void> refresh() => _fetch(withSummary: true);

  void updateSearch(String value) {
    final normalized = value.trim();
    if (normalized == state.search) return;
    emit(state.copyWith(search: normalized, page: 0));
    _searchTimer?.cancel();
    if (normalized.isEmpty) {
      _fetch(withSummary: false);
      return;
    }
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _fetch(withSummary: false),
    );
  }

  void setType(NotificationTypeFilter type) {
    if (type == state.type) return;
    emit(state.copyWith(type: type, page: 0));
    _fetch(withSummary: false);
  }

  void setReadFilter(NotificationReadFilter filter) {
    if (filter == state.readFilter) return;
    emit(state.copyWith(readFilter: filter, page: 0));
    _fetch(withSummary: false);
  }

  void setPushFilter(NotificationPushFilter filter) {
    if (filter == state.pushFilter) return;
    emit(state.copyWith(pushFilter: filter, page: 0));
    _fetch(withSummary: false);
  }

  void setPage(int page) {
    final maxPage = state.pages == 0 ? 0 : state.pages - 1;
    final target = page.clamp(0, maxPage);
    if (target == state.page) return;
    emit(state.copyWith(page: target));
    _fetch(withSummary: false);
  }

  void clearFilters() {
    _searchTimer?.cancel();
    if (!state.hasActiveFilters) return;
    emit(
      state.copyWith(
        search: '',
        type: NotificationTypeFilter.all,
        readFilter: NotificationReadFilter.all,
        pushFilter: NotificationPushFilter.all,
        page: 0,
      ),
    );
    _fetch(withSummary: false);
  }

  Future<List<AdminNotificationComposerCustomer>> searchCustomers(
    String search,
  ) => _repository.loadCustomers(search: search, limit: 20);

  Future<AdminAudienceEstimate> estimateAudience({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  }) => _repository.loadAudience(
    type: type,
    audience: audience,
    customerId: customerId,
  );

  Future<AdminSendResult> send(AdminNotificationDraft draft) async {
    final result = await _repository.sendNotification(
      type: draft.type,
      titleAr: draft.titleAr,
      titleEn: draft.titleEn,
      bodyAr: draft.bodyAr,
      bodyEn: draft.bodyEn,
      audience: draft.audience,
      customerId: draft.customerId,
      payload: draft.payload,
    );
    if (result.ok) {
      emit(state.copyWith(page: 0));
      await _fetch(withSummary: true);
    }
    return result;
  }

  Future<AdminResendResult> resend(String notificationId) async {
    final result = await _repository.resendNotification(notificationId);
    if (result.ok) await _fetch(withSummary: true);
    return result;
  }

  Future<NotificationMutationOutcome> setRead(
    String notificationId,
    bool read,
  ) async {
    final outcome = await _repository.setRead(notificationId, read);
    if (outcome == NotificationMutationOutcome.success) {
      await _fetch(withSummary: true);
    }
    return outcome;
  }

  Future<NotificationMutationOutcome> delete(String notificationId) async {
    final outcome = await _repository.deleteNotification(notificationId);
    if (outcome == NotificationMutationOutcome.success) {
      final targetPage = state.notifications.length == 1 && state.page > 0
          ? state.page - 1
          : state.page;
      emit(state.copyWith(page: targetPage));
      await _fetch(withSummary: true);
    }
    return outcome;
  }

  Future<void> _fetch({required bool withSummary, bool first = false}) async {
    final request = ++_requestId;
    if (first) {
      emit(
        state.copyWith(
          status: AdminNotificationsPageStatus.loading,
          clearError: true,
          isRefreshingRows: false,
        ),
      );
    } else {
      emit(state.copyWith(isRefreshingRows: true, clearError: true));
    }

    final rowsFuture = _repository.loadNotifications(
      search: state.search,
      type: state.type.value,
      isRead: state.readFilter.value,
      pushState: state.pushFilter.value,
      page: state.page,
      pageSize: state.pageSize,
    );
    final summaryFuture = withSummary
        ? Future.wait<Object?>([_loadMetricsSafely(), _loadHealthSafely()])
        : Future.value(<Object?>[null, null]);

    AdminNotificationPage? page;
    Object? failure;
    try {
      page = await rowsFuture;
    } catch (error) {
      failure = error;
    }
    final summary = await summaryFuture;
    if (isClosed || request != _requestId) return;

    final metrics = summary[0] as AdminNotificationMetrics?;
    final health = summary[1] as AdminPushHealth?;

    if (page == null) {
      final hasData = state.hasData;
      emit(
        state.copyWith(
          status: hasData
              ? AdminNotificationsPageStatus.ready
              : AdminNotificationsPageStatus.failure,
          metrics: metrics,
          pushHealth: health,
          isRefreshingRows: false,
          errorMessage: '$failure',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AdminNotificationsPageStatus.ready,
        notifications: page.rows,
        total: page.total,
        metrics: metrics,
        pushHealth: health,
        isRefreshingRows: false,
        clearError: true,
      ),
    );
  }

  Future<AdminNotificationMetrics?> _loadMetricsSafely() async {
    try {
      return await _repository.loadMetrics();
    } catch (_) {
      return null;
    }
  }

  Future<AdminPushHealth?> _loadHealthSafely() async {
    try {
      return await _repository.loadPushHealth();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
