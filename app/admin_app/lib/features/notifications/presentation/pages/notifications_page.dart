import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_cubit.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_state.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_actions_menu.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_compose_dialog.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_details_dialog.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_directory.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_page_body.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_push_setup_dialog.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.searchController,
    this.canSend = false,
    this.canManage = false,
    this.cubit,
  });

  static const String routeName = '/notifications';

  final AdminSearchController searchController;
  final bool canSend;
  final bool canManage;
  final AdminNotificationsCubit? cubit;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final AdminNotificationsCubit _cubit;
  late final bool _ownsCubit;
  final Set<String> _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminNotificationsCubit();
    if (_ownsCubit) _load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  Future<void> _load() => _cubit.load();

  Future<void> _refresh() => _cubit.refresh();

  void _onSearch(String query) => _cubit.updateSearch(query);

  void _onDirectorySearch(String value) {
    _cubit.updateSearch(value);
    widget.searchController.update(value);
  }

  void _clearFilters() {
    _cubit.clearFilters();
    widget.searchController.clear();
  }

  void _openSetup() {
    showNotificationPushSetupDialog(
      context: context,
      health: _cubit.state.pushHealth,
    );
  }

  Future<void> _compose() async {
    final result = await showNotificationComposeDialog(
      context: context,
      cubit: _cubit,
    );
    if (!mounted || result == null) return;
    _showMessage(
      S.notificationsSendSuccess(result.recipients, result.pushReady),
    );
  }

  Future<void> _openDetails(AdminNotification notification) async {
    final action = await showNotificationDetailsDialog(
      context: context,
      notification: notification,
      canSend: widget.canSend,
      canManage: widget.canManage,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case NotificationDetailsAction.toggleRead:
        await _toggleRead(notification);
      case NotificationDetailsAction.resend:
        await _resend(notification);
      case NotificationDetailsAction.delete:
        await _delete(notification);
    }
  }

  void _handleAction(
    AdminNotification notification,
    NotificationAction action,
  ) {
    switch (action) {
      case NotificationAction.details:
        _openDetails(notification);
      case NotificationAction.toggleRead:
        _toggleRead(notification);
      case NotificationAction.resend:
        _resend(notification);
      case NotificationAction.delete:
        _delete(notification);
    }
  }

  Future<void> _toggleRead(AdminNotification notification) async {
    if (!_pending.add(notification.id)) return;
    try {
      final outcome = await _cubit.setRead(
        notification.id,
        !notification.isRead,
      );
      if (!mounted) return;
      switch (outcome) {
        case NotificationMutationOutcome.success:
          _showMessage(
            notification.isRead
                ? S.notificationsMarkedUnreadToast
                : S.notificationsMarkedReadToast,
          );
        case NotificationMutationOutcome.notFound:
          _showMessage(S.notificationsNotFound, error: true);
        case NotificationMutationOutcome.failed:
          _showMessage(S.notificationsToggleFailed, error: true);
      }
    } finally {
      _pending.remove(notification.id);
    }
  }

  Future<void> _resend(AdminNotification notification) async {
    if (!_pending.add(notification.id)) return;
    try {
      final result = await _cubit.resend(notification.id);
      if (!mounted) return;
      if (result.ok && result.queued) {
        _showMessage(S.notificationsResendQueued);
        return;
      }
      final reason = result.reason;
      if (reason == 'push_not_configured') {
        _showMessage(S.notificationsResendNotConfigured);
        return;
      }
      if (reason == 'not_found') {
        _showMessage(S.notificationsNotFound, error: true);
        return;
      }
      _showMessage(S.notificationsResendFailed, error: true);
    } finally {
      _pending.remove(notification.id);
    }
  }

  Future<void> _delete(AdminNotification notification) async {
    if (_pending.contains(notification.id)) return;
    final confirmed = await _confirmDelete(notification);
    if (confirmed != true || !mounted) return;
    _pending.add(notification.id);
    try {
      final outcome = await _cubit.delete(notification.id);
      if (!mounted) return;
      switch (outcome) {
        case NotificationMutationOutcome.success:
          _showMessage(S.notificationsDeletedToast);
        case NotificationMutationOutcome.notFound:
          _showMessage(S.notificationsNotFound, error: true);
        case NotificationMutationOutcome.failed:
          _showMessage(S.notificationsDeleteFailed, error: true);
      }
    } finally {
      _pending.remove(notification.id);
    }
  }

  Future<bool?> _confirmDelete(AdminNotification notification) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            S.notificationsDeleteTitle,
            style: TextStyle(
              fontSize: AppFontSizes.size15,
              fontWeight: AppFontWeights.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            S.notificationsDeleteMessage(
              notificationCustomerName(notification),
            ),
            style: const TextStyle(
              fontSize: AppFontSizes.size11_5,
              height: AppTextHeights.line1_6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.cancel),
            ),
            FilledButton(
              key: const Key('notification-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColor.errorColor,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                S.notificationsDeleteConfirm,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(localizeDigits(message)),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminNotificationsCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminNotificationsCubit, AdminNotificationsState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _load,
            );
          }
          return NotificationPageBody(
            metrics: state.metrics,
            health: state.pushHealth,
            canSend: widget.canSend,
            canManage: widget.canManage,
            refreshingHealth: state.isRefreshingRows,
            onCompose: _compose,
            onRecheck: _refresh,
            onSetup: _openSetup,
            errorMessage: state.isFailure ? state.errorMessage : null,
            onRefresh: _refresh,
            directory: NotificationDirectory(
              notifications: state.notifications,
              total: state.total,
              page: state.page,
              pages: state.pages,
              pageSize: state.pageSize,
              search: state.search,
              type: state.type,
              readFilter: state.readFilter,
              pushFilter: state.pushFilter,
              isRefreshingRows: state.isRefreshingRows,
              canSend: widget.canSend,
              canManage: widget.canManage,
              onSearchChanged: _onDirectorySearch,
              onTypeChanged: _cubit.setType,
              onReadChanged: _cubit.setReadFilter,
              onPushChanged: _cubit.setPushFilter,
              onClearFilters: _clearFilters,
              onPageChanged: _cubit.setPage,
              onOpen: _openDetails,
              onAction: _handleAction,
            ),
          );
        },
      ),
    );
  }
}
