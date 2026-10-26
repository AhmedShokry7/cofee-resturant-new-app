part of 'notification_details_dialog.dart';

class _Banner extends StatelessWidget {
  const _Banner({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = notificationTypeColor(notification.type);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          typeColor,
          notificationTypeSurface(notification.type),
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: typeColor.withValues(alpha: adminIsDark(theme) ? .35 : .16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AppIcon(
              notificationTypeIcon(notification.type),
              size: 20,
              color: adminFlagForeground(theme, typeColor),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationTitle(notification),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size14,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(height: AppSizes.px6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NotificationTypeBadge(type: notification.type),
                    NotificationReadBadge(isRead: notification.isRead),
                    NotificationPushBadge(state: notification.push.state),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          AppIcons.calendar03,
                          size: 12,
                          color: adminMutedColor(theme),
                        ),
                        const SizedBox(width: AppSizes.px4),
                        Text(
                          notificationDateLabel(notification.createdAt),
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalizedContent extends StatelessWidget {
  const _LocalizedContent({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final arabic = _LanguageBlock(
      label: S.notificationsDetailsArabic,
      title: notification.titleAr,
      body: notification.bodyAr,
      textDirection: TextDirection.rtl,
    );
    final english = _LanguageBlock(
      label: S.notificationsDetailsEnglish,
      title: notification.titleEn,
      body: notification.bodyEn,
      textDirection: TextDirection.ltr,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              arabic,
              const SizedBox(height: AppSizes.px10),
              english,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: arabic),
            const SizedBox(width: AppSizes.px10),
            Expanded(child: english),
          ],
        );
      },
    );
  }
}
