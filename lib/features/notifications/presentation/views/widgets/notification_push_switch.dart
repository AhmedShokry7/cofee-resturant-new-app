import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';

/// Flips the push channel and says what the phone answered.
///
/// Turning it on needs a system permission, so the request can be refused and
/// the switch then stays where it was. A switch that does nothing looks broken,
/// so the refusal is reported rather than swallowed.
///
/// Both places that can change the channel - the bell in the app bar and the
/// banner above the list - run through here, so the two cannot tell the
/// customer different things about the same refusal.
Future<void> togglePushAndReport(BuildContext context, bool enabled) async {
  final cubit = context.read<NotificationsCubit>();
  final requested = !enabled;
  await cubit.setPushEnabled(requested);
  if (!context.mounted || cubit.state.pushEnabled == requested) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        requested ? S.notificationPermissionDenied : S.notificationsTurnedOff,
      ),
    ),
  );
}

/// The bell of the app bar: the channel of this customer, one tap away.
class NotificationPushToggle extends StatelessWidget {
  const NotificationPushToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      buildWhen: (previous, current) =>
          previous.pushEnabled != current.pushEnabled ||
          previous.signedOut != current.signedOut,
      builder: (context, state) {
        if (state.signedOut) return const SizedBox.shrink();
        final enabled = state.pushEnabled;
        return IconButton(
          key: const ValueKey('notification-push-toggle'),
          tooltip: enabled ? S.turnOffNotifications : S.turnOnNotifications,
          icon: Icon(
            enabled ? AppIcons.notification : AppIcons.notificationOff,
          ),
          onPressed: () => togglePushAndReport(context, enabled),
        );
      },
    );
  }
}
