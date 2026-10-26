part of 'notification_details_dialog.dart';

class _Footer extends StatelessWidget {
  const _Footer({
    required this.notification,
    required this.canSend,
    required this.canManage,
  });

  final AdminNotification notification;
  final bool canSend;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canManage)
            TextButton.icon(
              key: const Key('notification-details-delete'),
              onPressed: () =>
                  Navigator.of(context).pop(NotificationDetailsAction.delete),
              icon: const AppIcon(
                AppIcons.delete02,
                size: 15,
                color: AppColor.errorColor,
              ),
              label: Text(
                S.notificationsDelete,
                style: const TextStyle(
                  color: AppColor.errorColor,
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.close),
          ),
          if (canManage)
            OutlinedButton.icon(
              key: const Key('notification-details-toggle-read'),
              onPressed: () =>
                  Navigator.of(context)
                      .pop(NotificationDetailsAction.toggleRead),
              icon: AppIcon(
                notification.isRead
                    ? AppIcons.circle
                    : AppIcons.checkmarkCircle02,
                size: 15,
                color: adminBodyColor(theme),
              ),
              label: Text(
                notification.isRead
                    ? S.notificationsMarkUnread
                    : S.notificationsMarkRead,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          if (canSend)
            FilledButton.icon(
              key: const Key('notification-details-resend'),
              onPressed: () =>
                  Navigator.of(context).pop(NotificationDetailsAction.resend),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const AppIcon(
                AppIcons.sent,
                size: 15,
                color: AppColor.whiteColor,
              ),
              label: Text(
                S.notificationsResend,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

