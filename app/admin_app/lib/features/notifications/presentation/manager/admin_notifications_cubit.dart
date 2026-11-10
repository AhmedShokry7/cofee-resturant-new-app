import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/notifications/data/services/notifications_realtime_feed.dart';
import 'package:admin_app/features/notifications/di/notifications_dependencies.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:admin_app/features/notifications/domain/usecases/campaign_image.dart';
import 'package:admin_app/features/notifications/domain/usecases/delete_notification.dart';
import 'package:admin_app/features/notifications/domain/usecases/load_audience.dart';
import 'package:admin_app/features/notifications/domain/usecases/load_customers.dart';
import 'package:admin_app/features/notifications/domain/usecases/load_metrics.dart';
import 'package:admin_app/features/notifications/domain/usecases/load_notifications.dart';
import 'package:admin_app/features/notifications/domain/usecases/load_push_health.dart';
import 'package:admin_app/features/notifications/domain/usecases/resend_notification.dart';
import 'package:admin_app/features/notifications/domain/usecases/send_notification.dart';
import 'package:admin_app/features/notifications/domain/usecases/set_read.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_state.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';

class AdminNotificationsCubit extends Cubit<AdminNotificationsState> {
  AdminNotificationsCubit({
    NotificationsRepository? repository,
    NotificationsRealtimeFeed? realtimeFeed,
  }) : this._withUseCases(
         repository ?? NotificationsDependencies.repository,
         realtimeFeed,
       );

  AdminNotificationsCubit._withUseCases(
    NotificationsRepository repository,
    NotificationsRealtimeFeed? realtimeFeed,
  ) : _loadNotifications = LoadNotificationsUseCase(repository),
      _loadMetrics = LoadMetricsUseCase(repository),
      _loadPushHealth = LoadPushHealthUseCase(repository),
      _loadCustomers = LoadCustomersUseCase(repository),
      _loadAudience = LoadAudienceUseCase(repository),
      _sendNotification = SendNotificationUseCase(repository),
      _resendNotification = ResendNotificationUseCase(repository),
      _setRead = SetReadUseCase(repository),
      _deleteNotification = DeleteNotificationUseCase(repository),
      _uploadCampaignImage = UploadCampaignImageUseCase(repository),
      _discardCampaignImage = DiscardCampaignImageUseCase(repository),
      _realtimeFeed = realtimeFeed ?? NotificationsRealtimeFeed(),
      super(const AdminNotificationsState());

  final LoadNotificationsUseCase _loadNotifications;
  final LoadMetricsUseCase _loadMetrics;
  final LoadPushHealthUseCase _loadPushHealth;
  final LoadCustomersUseCase _loadCustomers;
  final LoadAudienceUseCase _loadAudience;
  final SendNotificationUseCase _sendNotification;
  final ResendNotificationUseCase _resendNotification;
  final SetReadUseCase _setRead;
  final DeleteNotificationUseCase _deleteNotification;
  final UploadCampaignImageUseCase _uploadCampaignImage;
  final DiscardCampaignImageUseCase _discardCampaignImage;
  final NotificationsRealtimeFeed _realtimeFeed;
  Timer? _searchTimer;
  int _requestId = 0;
  bool _liveStarted = false;

  /// Listens to `engagement.notifications` so a campaign sent from another
  /// screen, or a customer reading a message, moves the directory without a
  /// manual reload. Starting it twice is a no-op: one page owns one channel.
  void startLiveUpdates() {
    if (_liveStarted) return;
    _liveStarted = true;
    _realtimeFeed.start(_onLiveChange);
  }

  void _onLiveChange() {
    if (isClosed) return;
    refresh();
  }

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

  void setCampaignFilter(NotificationCampaignFilter filter) {
    if (filter == state.campaignFilter) return;
    emit(state.copyWith(campaignFilter: filter, page: 0));
    _fetch(withSummary: false);
  }

  void setDateFilter(DateTime? from, DateTime? to) {
    if (_sameDate(state.dateFrom, from) && _sameDate(state.dateTo, to)) return;
    emit(
      state.copyWith(
        dateFrom: from,
        dateTo: to,
        clearDateFilter: from == null && to == null,
        page: 0,
      ),
    );
    _fetch(withSummary: false);
  }

  bool _sameDate(DateTime? left, DateTime? right) =>
      left?.year == right?.year &&
      left?.month == right?.month &&
      left?.day == right?.day;

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
        campaignFilter: NotificationCampaignFilter.all,
        clearDateFilter: true,
        page: 0,
      ),
    );
    _fetch(withSummary: false);
  }

  Future<List<AdminNotificationComposerCustomer>> searchCustomers(
    String search,
  ) => _loadCustomers(search: search, limit: 20);

  Future<AdminAudienceEstimate> estimateAudience({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  }) => _loadAudience(type: type, audience: audience, customerId: customerId);

  /// يرفع صورة الحملة ويعيد رابطها العام، ليحمله الحقل المرفوع في المسودة.
  Future<String> uploadCampaignImage({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) => _uploadCampaignImage(
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
  );

  /// يتخلى عن صورة رُفعت ثم لم تُرسل. خطأ الحذف لا يوقف شيء: الملف يبقى في
  /// الدلو بلا صف يشير إليه، والإشعار الذي أُرسل فعلًا لا يُمسّ هنا.
  Future<void> discardCampaignImage(String? imageUrl) async {
    try {
      await _discardCampaignImage(imageUrl);
    } catch (_) {}
  }

  Future<AdminSendResult> send(AdminNotificationDraft draft) async {
    final result = await _sendNotification(
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
    final result = await _resendNotification(notificationId);
    if (result.ok) await _fetch(withSummary: true);
    return result;
  }

  Future<NotificationMutationOutcome> setRead(
    String notificationId,
    bool read,
  ) async {
    final outcome = await _setRead(notificationId, read);
    if (outcome == NotificationMutationOutcome.success) {
      await _fetch(withSummary: true);
    }
    return outcome;
  }

  Future<NotificationMutationOutcome> delete(String notificationId) async {
    final outcome = await _deleteNotification(notificationId);
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

    final rowsFuture = _loadNotifications(
      search: state.search,
      type: state.type.value,
      isRead: state.readFilter.value,
      pushState: state.pushFilter.value,
      source: state.campaignFilter.value,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
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
          errorMessage: failure == null ? null : adminErrorMessage(failure),
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
      return await _loadMetrics();
    } catch (_) {
      return null;
    }
  }

  Future<AdminPushHealth?> _loadHealthSafely() async {
    try {
      return await _loadPushHealth();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _searchTimer?.cancel();
    _liveStarted = false;
    await _realtimeFeed.dispose();
    return super.close();
  }
}
