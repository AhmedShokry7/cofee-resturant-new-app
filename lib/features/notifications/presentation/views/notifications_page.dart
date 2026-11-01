import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_preferences_sheet.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
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
      // The switch of the push belongs to the customer, so it is read from
      // the server instead of being remembered on the device.
      context.read<NotificationsCubit>().loadPushState();
    });
  }

  /// Turns the push on or off and says what happened.
  ///
  /// Turning it on needs the permission of the system, so it can be refused.
  /// A refusal that leaves the switch where it was is reported, because a
  /// switch that does nothing looks broken.
  Future<void> _togglePush(BuildContext context, bool enabled) async {
    final cubit = context.read<NotificationsCubit>();
    final requested = !enabled;
    await cubit.setPushEnabled(requested);
    if (!context.mounted) return;
    if (cubit.state.pushEnabled == requested) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requested ? S.notificationPermissionDenied : S.notificationsTurnedOff,
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
            title: Text(S.notifications),
            actions: [
              if (!state.signedOut)
                IconButton(
                  tooltip: S.notificationPreferences,
                  icon: const Icon(HugeIcons.strokeRoundedSettings01),
                  onPressed: () => showNotificationPreferencesSheet(context),
                ),
              BlocBuilder<NotificationsCubit, NotificationsState>(
                buildWhen: (previous, current) =>
                    previous.pushEnabled != current.pushEnabled ||
                    previous.signedOut != current.signedOut,
                builder: (context, cubitState) {
                  if (cubitState.signedOut) return const SizedBox.shrink();
                  final enabled = cubitState.pushEnabled;
                  return IconButton(
                    tooltip: enabled
                        ? S.turnOffNotifications
                        : S.turnOnNotifications,
                    icon: Icon(
                      enabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    onPressed: () => _togglePush(context, enabled),
                  );
                },
              ),
            ],
          ),
          body: Builder(
            builder: (context) {
              if (state.isLoading && state.notifications.isEmpty) {
                return const NotificationsSkeleton();
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
                padding: LayoutTokens.pageBody(),
                children: state.notifications
                    .map(
                      (notification) => NotificationTile(
                        notification: notification,
                        isRead: notification.isRead,
                        onTap: () {
                          final route = routeForNotification(
                            relatedEntityType: notification.relatedEntityType,
                            type: notification.type,
                            destination: notification.destination,
                          );
                          if (route != null) {
                            Navigator.of(context).pushNamed(route);
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        );
      },
    );
  }
}
