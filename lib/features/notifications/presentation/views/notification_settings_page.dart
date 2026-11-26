import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_preferences_sheet.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

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
            appBar: AppBar(
              leading: const AppBackButton(),
              title: DesignText(
                S.notificationPreferences,
                page: 'notification_settings',
                label: 'notificationPreferences',
              ),
            ),
            body: state.signedOut
                ? const AuthRequiredView(
                    originRoute: NotificationSettingsPage.routeName,
                  )
                : !state.preferencesRead
                ? const Center(child: CircularProgressIndicator())
                : state.preferencesLoadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.px20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DesignText(
                            S.notificationPreferencesLoadFailed,
                            page: 'notification_settings',
                            label: 'notificationPreferencesLoadFailed',
                          ),
                          const SizedBox(height: AppSizes.px12),
                          CustomTextButton(
                            onPressed: () => context
                                .read<NotificationsCubit>()
                                .loadPushState(),
                            child: DesignText(
                              S.tryAgain,
                              page: 'notification_settings',
                              label: 'tryAgain',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.px20),
                    child: NotificationPreferencesPanel(),
                  ),
          );
        },
      );
}
