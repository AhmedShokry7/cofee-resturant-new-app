import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notifications_page_body.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

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
  void _toggleSelection(String id) {
    context.read<NotificationsCubit>().toggleSelection(id);
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
        title: DesignText(
          S.notificationDeleteAll,
          page: 'notifications',
          label: 'notificationDeleteAll',
        ),
        content: DesignText(
          S.notificationDeleteAllConfirm,
          page: 'notifications',
          label: 'notificationDeleteAllConfirm',
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: DesignText(S.cancel, page: 'notifications', label: 'cancel'),
          ),
          CustomTextButton(
            onPressed: () => Navigator.pop(context, true),
            child: DesignText(S.delete, page: 'notifications', label: 'delete'),
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
            leading: const AppBackButton(),
            title: Text(
              state.selectedIds.isEmpty
                  ? S.notifications
                  : S.notificationSelectionCount(state.selectedIds.length),
            ),
            actions: [
              if (state.selectedIds.isNotEmpty) ...[
                CustomIconButton(
                  tooltip: S.notificationDeleteSelected,
                  icon: const Icon(AppIcons.delete),
                  onPressed: _deleteSelected,
                ),
                CustomIconButton(
                  tooltip: S.notificationCancelSelection,
                  icon: const Icon(AppIcons.close),
                  onPressed: () =>
                      context.read<NotificationsCubit>().clearSelection(),
                ),
              ] else ...[
                if (state.unreadCount > 0)
                  CustomIconButton(
                    key: const ValueKey('notification-mark-all'),
                    tooltip: S.notificationMarkAllRead,
                    icon: const Icon(AppIcons.checkmark),
                    onPressed: () =>
                        context.read<NotificationsCubit>().markAllRead(),
                  ),
                if (state.notifications.isNotEmpty || state.hasMore)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete_all') _deleteAll();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete_all',
                        child: DesignText(
                          S.notificationDeleteAll,
                          page: 'notifications',
                          label: 'notificationDeleteAll',
                        ),
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
