import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const routeName = "notificationsRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.notifications)),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          // Opening the page marks everything seen, through the server RPC
          // rather than device-only flags.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<NotificationsCubit>().markAllRead();
            }
          });
          if (state.isLoading && state.notifications.isEmpty) {
            return const NotificationsSkeleton();
          }
          if (state.signedOut) {
            return EmptyState(
              icon: Icons.notifications_outlined,
              title: S.signInForNotifications,
              subtitle: S.orderUpdatesAccount,
            );
          }
          if (state.error != null && state.notifications.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_outlined,
              title: S.couldNotLoadNotifications,
              subtitle: state.error,
            );
          }
          if (state.notifications.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_outlined,
              title: S.noNotifications,
              subtitle: S.notificationsHint,
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            children: state.notifications
                .map(
                  (notification) => NotificationTile(
                    notification: notification,
                    isRead: notification.isRead,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
