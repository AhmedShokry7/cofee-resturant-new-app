import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_preferences_sheet.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  static const routeName = 'notificationSettingsRoute';

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsCubit>().loadPushState();
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(S.notificationPreferences)),
            body: state.signedOut
                ? const AuthRequiredView(
                    originRoute: NotificationSettingsPage.routeName,
                  )
                : !state.preferencesRead
                ? const Center(child: CircularProgressIndicator())
                : state.preferencesLoadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(S.notificationPreferencesLoadFailed),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context
                                .read<NotificationsCubit>()
                                .loadPushState(),
                            child: Text(S.tryAgain),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: NotificationPreferencesPanel(),
                  ),
          );
        },
      );
}
