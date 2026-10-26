part of 'review_details_dialog.dart';

class _Footer extends StatelessWidget {
  const _Footer({required this.review, required this.canManage});

  final AdminReview review;
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
              key: const Key('review-details-delete'),
              onPressed: () =>
                  Navigator.of(context).pop(ReviewDetailsAction.delete),
              icon: const AppIcon(
                AppIcons.delete02,
                size: 15,
                color: AppColor.errorColor,
              ),
              label: Text(
                S.reviewsDelete,
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
            FilledButton.icon(
              key: const Key('review-details-toggle'),
              onPressed: () =>
                  Navigator.of(context)
                      .pop(ReviewDetailsAction.togglePublished),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: AppIcon(
                review.isPublished
                    ? AppIcons.eyeOff
                    : AppIcons.checkmarkCircle02,
                size: 15,
                color: AppColor.whiteColor,
              ),
              label: Text(
                review.isPublished ? S.reviewsHide : S.reviewsPublish,
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
