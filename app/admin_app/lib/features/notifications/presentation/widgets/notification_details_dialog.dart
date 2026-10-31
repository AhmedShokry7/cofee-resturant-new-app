import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_badges.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

part 'notification_details_banner_localized_content.dart';
part 'notification_details_language_block_customer_card.dart';
part 'notification_details_source_card_push_card.dart';
part 'notification_details_count_chip_payload_card.dart';
part 'notification_details_footer.dart';

enum NotificationDetailsAction { toggleRead, resend, delete }

Future<NotificationDetailsAction?> showNotificationDetailsDialog({
  required BuildContext context,
  required AdminNotification notification,
  required bool canSend,
  required bool canManage,
}) {
  return showDialog<NotificationDetailsAction>(
    context: context,
    builder: (_) => NotificationDetailsDialog(
      notification: notification,
      canSend: canSend,
      canManage: canManage,
    ),
  );
}

class NotificationDetailsDialog extends StatelessWidget {
  const NotificationDetailsDialog({
    super.key,
    required this.notification,
    required this.canSend,
    required this.canManage,
  });

  final AdminNotification notification;
  final bool canSend;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .88, 780.0);
    return Dialog(
      key: const Key('notification-details-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < AppBreakpoints.pageCanvas
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: S.notificationsDetailsTitle,
                subtitle: S.notificationsDetailsSubtitle(
                  notificationCustomerName(notification),
                ),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Banner(notification: notification),
                      const SizedBox(height: AppSizes.px16),
                      _SectionLabel(label: S.notificationsDetailsContent),
                      const SizedBox(height: AppSizes.px8),
                      _LocalizedContent(notification: notification),
                      const SizedBox(height: AppSizes.px16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final customer = _CustomerCard(
                            notification: notification,
                          );
                          final source = _SourceCard(
                            notification: notification,
                          );
                          if (constraints.maxWidth < 620) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                customer,
                                const SizedBox(height: AppSizes.px10),
                                source,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: customer),
                              const SizedBox(width: AppSizes.px10),
                              Expanded(child: source),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.px10),
                      _PushCard(notification: notification),
                      const SizedBox(height: AppSizes.px10),
                      _PayloadCard(notification: notification),
                      const SizedBox(height: AppSizes.px14),
                      _MetaLine(
                        label: S.notificationsDetailsCreated,
                        value: notificationDateTimeLabel(
                          notification.createdAt,
                        ),
                      ),
                      const SizedBox(height: AppSizes.px6),
                      _MetaLine(
                        label: S.notificationsDetailsReadAt,
                        value: notification.readAt == null
                            ? S.notificationsDetailsNeverRead
                            : notificationDateTimeLabel(notification.readAt),
                      ),
                      if (notification.relatedEntityId != null) ...[
                        const SizedBox(height: AppSizes.px6),
                        _MetaLine(
                          label: S.notificationsDetailsRelated,
                          value: [
                            ?notificationRelatedLabel(
                              notification.relatedEntityType,
                            ),
                            notification.relatedEntityId!,
                          ].join(' • '),
                        ),
                      ],
                      if (canSend) ...[
                        const SizedBox(height: AppSizes.px12),
                        Text(
                          S.notificationsDetailsResendHint,
                          style: TextStyle(
                            color: adminMutedColor(Theme.of(context)),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Footer(
                notification: notification,
                canSend: canSend,
                canManage: canManage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
