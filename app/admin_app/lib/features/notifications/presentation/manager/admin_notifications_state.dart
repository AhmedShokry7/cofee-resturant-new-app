import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';

enum AdminNotificationsPageStatus { initial, loading, ready, failure }

class AdminNotificationsState {
  const AdminNotificationsState({
    this.status = AdminNotificationsPageStatus.initial,
    this.notifications = const <AdminNotification>[],
    this.total = 0,
    this.metrics = AdminNotificationMetrics.empty,
    this.pushHealth = const AdminPushHealth(),
    this.search = '',
    this.type = NotificationTypeFilter.all,
    this.readFilter = NotificationReadFilter.all,
    this.pushFilter = NotificationPushFilter.all,
    this.campaignFilter = NotificationCampaignFilter.all,
    this.dateFrom,
    this.dateTo,
    this.page = 0,
    this.pageSize = AdminNotificationsPaging.pageSize,
    this.isRefreshingRows = false,
    this.errorMessage,
    this.selectedIds = const <String>{},
    this.selectedAllMatching = false,
    this.isBulkBusy = false,
  });

  final AdminNotificationsPageStatus status;
  final List<AdminNotification> notifications;

  /// The number of rows the server matched, across every page.
  final int total;
  final AdminNotificationMetrics metrics;
  final AdminPushHealth pushHealth;
  final String search;
  final NotificationTypeFilter type;
  final NotificationReadFilter readFilter;
  final NotificationPushFilter pushFilter;
  final NotificationCampaignFilter campaignFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int page;
  final int pageSize;
  final bool isRefreshingRows;
  final String? errorMessage;

  /// Notification ids selected for bulk delete. Only deletable rows appear here.
  final Set<String> selectedIds;

  /// True when the selection was made with "select all matching", so it covers
  /// every page of the current filters rather than only the visible rows.
  final bool selectedAllMatching;

  /// True while a bulk selection lookup or delete is running. Blocks repeats.
  final bool isBulkBusy;

  bool get isLoading => status == AdminNotificationsPageStatus.loading;
  bool get isFailure => status == AdminNotificationsPageStatus.failure;

  bool get hasData =>
      notifications.isNotEmpty || total > 0 || metrics.total > 0;

  int get pages => total <= 0 ? 0 : (total + pageSize - 1) ~/ pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      type != NotificationTypeFilter.all ||
      readFilter != NotificationReadFilter.all ||
      pushFilter != NotificationPushFilter.all ||
      campaignFilter != NotificationCampaignFilter.all ||
      dateFrom != null ||
      dateTo != null;

  AdminNotificationsState copyWith({
    AdminNotificationsPageStatus? status,
    List<AdminNotification>? notifications,
    int? total,
    AdminNotificationMetrics? metrics,
    AdminPushHealth? pushHealth,
    String? search,
    NotificationTypeFilter? type,
    NotificationReadFilter? readFilter,
    NotificationPushFilter? pushFilter,
    NotificationCampaignFilter? campaignFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? page,
    bool? isRefreshingRows,
    String? errorMessage,
    bool clearError = false,
    bool clearDateFilter = false,
    Set<String>? selectedIds,
    bool? selectedAllMatching,
    bool? isBulkBusy,
    bool clearSelection = false,
  }) {
    return AdminNotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      total: total ?? this.total,
      metrics: metrics ?? this.metrics,
      pushHealth: pushHealth ?? this.pushHealth,
      search: search ?? this.search,
      type: type ?? this.type,
      readFilter: readFilter ?? this.readFilter,
      pushFilter: pushFilter ?? this.pushFilter,
      campaignFilter: campaignFilter ?? this.campaignFilter,
      dateFrom: clearDateFilter ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateFilter ? null : (dateTo ?? this.dateTo),
      page: page ?? this.page,
      pageSize: pageSize,
      isRefreshingRows: isRefreshingRows ?? this.isRefreshingRows,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedIds: clearSelection
          ? const <String>{}
          : (selectedIds ?? this.selectedIds),
      selectedAllMatching: clearSelection
          ? false
          : (selectedAllMatching ?? this.selectedAllMatching),
      isBulkBusy: isBulkBusy ?? this.isBulkBusy,
    );
  }
}
