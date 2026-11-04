import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_preferences_sheet.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_push_switch.dart';
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
  /// Reads the switches of the customer when the screen opens.
  ///
  /// They belong to the account, not to this phone, so the bell and the banner
  /// are drawn from the server row rather than from anything stored locally.
  ///
  /// This runs from [State.initState], a lifecycle callback: an earlier version
  /// ran it from a post-frame callback registered inside a `builder`, which
  /// meant every emission scheduled another one.
  ///
  /// Marking nothing read is deliberate too. Opening the page used to mark
  /// every row on it as seen, which cleared the dots before the customer had
  /// read a single message; rows are now marked where they are actually read -
  /// one at a time, on the tap - and the app bar offers the rest on purpose.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsCubit>().loadPushState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      buildWhen: (previous, current) =>
          previous.signedOut != current.signedOut ||
          previous.unreadCount != current.unreadCount,
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
              if (state.unreadCount > 0)
                IconButton(
                  key: const ValueKey('notification-mark-all'),
                  tooltip: S.notificationMarkAllRead,
                  icon: const Icon(AppIcons.checkmark),
                  onPressed: () =>
                      context.read<NotificationsCubit>().markAllRead(),
                ),
              const NotificationPushToggle(),
              IconButton(
                tooltip: S.notificationPreferences,
                icon: const Icon(AppIcons.settings),
                onPressed: () => showNotificationPreferencesSheet(context),
              ),
            ],
          ),
          body: const NotificationsPageBody(),
        );
      },
    );
  }
}
