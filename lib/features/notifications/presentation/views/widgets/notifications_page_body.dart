import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_day_header.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The scrolled part of the notifications screen.
///
/// The page owns the frame and the app bar; this owns what the state looks like
/// and nothing else. It never picks a route or writes a switch: it asks the
/// cubit, which is where the reading, the marking and the destination live.
class NotificationsPageBody extends StatelessWidget {
  const NotificationsPageBody({
    super.key,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  final Set<String> selectedIds;
  final ValueChanged<String> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        if (state.isLoading && state.notifications.isEmpty) {
          return const NotificationsSkeleton();
        }
        if (state.error != null && state.notifications.isEmpty) {
          return _Refreshable(
            children: [
              EmptyState(
                icon: AppIcons.notification,
                title: S.couldNotLoadNotifications,
                subtitle: state.error,
              ),
              CustomBtn(
                text: S.tryAgain,
                onPressed: () => context.read<NotificationsCubit>().load(),
              ),
            ],
          );
        }
        if (state.notifications.isEmpty) {
          return _Refreshable(
            children: [
              EmptyState(
                icon: AppIcons.notification,
                title: S.noNotifications,
                subtitle: S.notificationsHint,
              ),
            ],
          );
        }
        // The page is bounded by NotificationsCubit.pageSize rows, and the
        // rest only arrives when the customer asks, so the children of this
        // list cannot grow past one block per day plus a page of rows.
        return _Refreshable(
          children: [
            ..._dayBlocks(context, state.notifications),
            if (state.hasMore) _ShowMore(isLoading: state.isLoadingMore),
          ],
        );
      },
    );
  }

  /// The rows, with a heading wherever the day changes.
  ///
  /// The cubit hands them newest first, so the day of each row is compared with
  /// the day of the row before it and a heading is inserted at the change. Rows
  /// that carry no time are drawn without one rather than claimed for today.
  List<Widget> _dayBlocks(BuildContext context, List<NotificationModel> items) {
    final cubit = context.read<NotificationsCubit>();
    final children = <Widget>[];
    DateTime? previousDay;
    for (final item in items) {
      final day = deliveryDayOf(item);
      if (day != null && day != previousDay) {
        children.add(NotificationDayHeader(label: notificationDayLabel(day)));
      }
      previousDay = day;
      final isSelected = selectedIds.contains(item.id);
      children.add(
        Dismissible(
          key: ValueKey('notification-${item.id}'),
          direction: selectedIds.isEmpty
              ? (Directionality.of(context) == TextDirection.rtl
                    ? DismissDirection.endToStart
                    : DismissDirection.startToEnd)
              : DismissDirection.none,
          background: Container(
            margin: EdgeInsetsDirectional.only(bottom: AppSpacing.md),
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColor.errorColor,
              borderRadius: BorderRadius.circular(AppRadius.r16),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.delete, color: Colors.white),
                SizedBox(width: AppSpacing.xs),
                Text(S.delete, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            final deleted = await cubit.deleteNotification(item.id);
            if (!context.mounted || deleted) return deleted;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(S.notificationDeleteFailed)));
            return false;
          },
          child: NotificationTile(
            key: ValueKey('notification-card-${item.id}'),
            notification: item,
            isRead: item.isRead,
            isSelected: isSelected,
            onLongPress: () => onSelectionChanged(item.id),
            onTap: () {
              if (selectedIds.isNotEmpty) {
                onSelectionChanged(item.id);
                return;
              }
              final open = cubit.openFrom(item);
              if (open == null || !context.mounted) return;
              Navigator.of(context)
                  .pushNamed(open.route, arguments: open.entityId);
            },
          ),
        ),
      );
    }
    return children;
  }
}

/// Pull-to-refresh wrapped around a column that may be shorter than the screen.
class _Refreshable extends StatelessWidget {
  const _Refreshable({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<NotificationsCubit>().refresh(),
      child: ListView(
        padding: AppLayout.pageBody,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// The ask for the rows the server still holds.
///
/// A failed page leaves what is on screen alone and the button where it was, so
/// the customer can ask again rather than lose the list to one bad response.
class _ShowMore extends StatelessWidget {
  const _ShowMore({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('notification-show-more'),
      padding: EdgeInsetsDirectional.only(top: AppSpacing.xs),
      child: CustomBtn(
        text: S.notificationShowMore,
        isLoading: isLoading,
        onPressed: () => context.read<NotificationsCubit>().loadMore(),
      ),
    );
  }
}
