import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/data/models/admin_push_health.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_directory.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_metrics_cards.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_push_health_panel.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class NotificationPageBody extends StatelessWidget {
  const NotificationPageBody({
    super.key,
    required this.metrics,
    required this.health,
    required this.directory,
    required this.canSend,
    required this.canManage,
    required this.onCompose,
    required this.onRecheck,
    required this.onSetup,
    this.refreshingHealth = false,
    this.errorMessage,
    this.onRefresh,
  });

  final AdminNotificationMetrics metrics;
  final AdminPushHealth health;
  final NotificationDirectory directory;
  final bool canSend;
  final bool canManage;
  final VoidCallback onCompose;
  final VoidCallback onRecheck;
  final VoidCallback onSetup;
  final bool refreshingHealth;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 820;
          final sections = <Widget>[
            AdminPageHeader(
              title: S.notifications,
              subtitle: S.notificationsDescription,
              actions: [
                if (canSend)
                  CustomBtn(
                    key: const Key('notification-compose-open'),
                    text: S.notificationsCompose,
                    onPressed: onCompose,
                    leadingIcon: const Icon(
                      HugeIcons.strokeRoundedAdd01,
                      size: 18,
                    ),
                    height: 42,
                    borderRadius: AppDimensions.radiusPill,
                    backgroundColor: AppColor.primaryColor,
                    textColor: AppColor.whiteColor,
                  ),
              ],
              footer: canManage || canSend
                  ? null
                  : AdminReadOnlyHint(message: S.notificationsReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: 7),
            NotificationMetricsCards(metrics: metrics),
            const SizedBox(height: 14),
            NotificationPushHealthPanel(
              health: health,
              refreshing: refreshingHealth,
              onRecheck: onRecheck,
              onSetup: onSetup,
            ),
            const SizedBox(height: 14),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(height: 720, child: directory),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              Expanded(child: directory),
            ],
          );
        },
      ),
    );
  }
}
