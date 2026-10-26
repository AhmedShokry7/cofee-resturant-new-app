part of 'notification_details_dialog.dart';

class _LanguageBlock extends StatelessWidget {
  const _LanguageBlock({
    required this.label,
    required this.title,
    required this.body,
    required this.textDirection,
  });

  final String label;
  final String? title;
  final String? body;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size8_5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_4,
                letterSpacing: AppLetterSpacings.space0_2,
              ),
            ),
            const SizedBox(height: AppSizes.px6),
            Text(
              title ?? '—',
              style: TextStyle(
                color: title == null
                    ? adminMutedColor(theme)
                    : adminHeadingColor(theme),
                fontSize: AppFontSizes.size11_5,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
            const SizedBox(height: AppSizes.px4),
            Text(
              body ?? '—',
              style: TextStyle(
                color: body == null
                    ? adminMutedColor(theme)
                    : adminBodyColor(theme),
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = notification.customer;
    return _InfoCard(
      title: S.notificationsDetailsCustomer,
      child: Row(
        children: [
          AdminAvatarImage(
            url: customer.avatarUrl,
            size: 40,
            fallbackText: notificationCustomerInitial(notification),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationCustomerName(notification),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (customer.email != null)
                  Text(
                    customer.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                if (customer.phone != null)
                  Text(
                    customer.phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
