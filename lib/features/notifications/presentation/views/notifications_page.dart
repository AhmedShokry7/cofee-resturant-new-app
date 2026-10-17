import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  static const routeName = "notificationsRoute";

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  /// Opening the page marks what is on screen as seen, through the server RPC
  /// rather than device-only flags.
  ///
  /// This runs from [State.initState], so it happens once per visit. It used to
  /// run from a post-frame callback registered inside `BlocBuilder.builder`,
  /// which meant every emission scheduled another one and the page spun in an
  /// endless emit -> rebuild -> mark-as-read -> request loop. `initState` is a
  /// lifecycle callback, not a render callback, so no later emission can
  /// restart it, and the cubit still re-reads the list afterwards so the unread
  /// dots clear without losing the rows.
  ///
  /// Notifications that arrive later are not affected: only the ids that are
  /// unread at the moment of the call are written, and a future visit marks
  /// whatever is unread then.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsCubit>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.notifications)),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
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
