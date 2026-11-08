import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notifications_page_body.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';

/// The customer's own messages, and the switches that decide what is allowed to
/// reach the phone.
///
/// The screen reads nothing and writes nothing: it asks the cubit for the rows
/// and the switches, and every control hands the decision to it.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static const routeName = "notificationsRoute";

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<NotificationsCubit>().markAllRead());
    });
  }

  void _toggleSelection(String id) {
    context.read<NotificationsCubit>().toggleSelection(id);
  }

  Future<void> _selectAll(List<NotificationModel> notifications) async {
    final cubit = context.read<NotificationsCubit>();
    if (cubit.state.hasMore) await cubit.loadAll();
    if (!mounted) return;
    notifications = cubit.state.notifications;
    cubit.selectNotifications(notifications.map((item) => item.id));
  }

  Future<void> _deleteSelected() async {
    final cubit = context.read<NotificationsCubit>();
    final selectedIds = cubit.state.selectedIds;
    final count = selectedIds.length;
    if (count == 0) return;
    final deleted = await context
        .read<NotificationsCubit>()
        .deleteNotifications(selectedIds.toList());
    if (!mounted) return;
    cubit.clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0
              ? S.notificationDeletedCount(deleted)
              : S.notificationDeleteFailed,
        ),
      ),
    );
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.notificationDeleteAll),
        content: Text(S.notificationDeleteAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await context
        .read<NotificationsCubit>()
        .deleteAllNotifications();
    if (!mounted) return;
    context.read<NotificationsCubit>().clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0
              ? S.notificationDeletedCount(deleted)
              : S.notificationDeleteFailed,
        ),
      ),
    );
  }

  /// Reads the switches of the customer when the screen opens.
  ///
  /// They belong to the account, not to this phone, so the bell and the banner
  /// are drawn from the server row rather than from anything stored locally.
  ///
  /// This runs from [State.initState], a lifecycle callback: an earlier version
  /// ran it from a post-frame callback registered inside a `builder`, which
  /// meant every emission scheduled another one.
  ///
  /// Opening the page marks all notifications as read through the cubit.
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        if (state.signedOut) {
          return const AuthRequiredView(
            originRoute: NotificationsPage.routeName,
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.selectedIds.isEmpty
                  ? S.notifications
                  : S.notificationSelectionCount(state.selectedIds.length),
            ),
            actions: [
              if (state.selectedIds.isNotEmpty) ...[
                IconButton(
                  tooltip: S.notificationDeleteSelected,
                  icon: const Icon(AppIcons.delete),
                  onPressed: _deleteSelected,
                ),
                IconButton(
                  tooltip: S.notificationCancelSelection,
                  icon: const Icon(AppIcons.close),
                  onPressed: () =>
                      context.read<NotificationsCubit>().clearSelection(),
                ),
              ] else ...[
                if (state.unreadCount > 0)
                  IconButton(
                    key: const ValueKey('notification-mark-all'),
                    tooltip: S.notificationMarkAllRead,
                    icon: const Icon(AppIcons.checkmark),
                    onPressed: () =>
                        context.read<NotificationsCubit>().markAllRead(),
                  ),
                if (state.notifications.isNotEmpty)
                  IconButton(
                    tooltip: S.notificationSelectAll,
                    icon: const Icon(AppIcons.checkmarkCircle),
                    onPressed: () => _selectAll(state.notifications),
                  ),
                if (state.notifications.isNotEmpty || state.hasMore)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete_all') _deleteAll();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete_all',
                        child: Text(S.notificationDeleteAll),
                      ),
                    ],
                  ),
              ],
            ],
          ),
          body: NotificationsPageBody(
            selectedIds: state.selectedIds,
            onSelectionChanged: _toggleSelection,
          ),
        );
      },
    );
  }
}
