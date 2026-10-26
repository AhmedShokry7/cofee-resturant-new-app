part of 'review_details_dialog.dart';

class _RatingBanner extends StatelessWidget {
  const _RatingBanner({required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ReviewStars(
                  rating: review.rating.toDouble(),
                  size: 19,
                  showValue: true,
                ),
              ),
              ReviewStatusBadge(review: review),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (review.isVerifiedPurchase)
                const ReviewVerifiedChip()
              else
                const ReviewUnverifiedLabel(),
              _MetaChip(
                icon: AppIcons.calendar03,
                label: reviewDateLabel(review.createdAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 12, color: adminMutedColor(theme)),
        const SizedBox(width: AppSizes.px4),
        Text(
          label,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_4,
          ),
        ),
      ],
    );
  }
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final title = review.titleFor(language);
    final body = review.bodyFor(language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: S.reviewsDetailsComment),
        const SizedBox(height: AppSizes.px6),
        if (title != null)
          Text(
            title,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size16,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_5,
            ),
          ),
        if (title != null) const SizedBox(height: AppSizes.px6),
        Text(
          body ?? S.reviewsDetailsNoComment,
          style: TextStyle(
            color: body == null
                ? adminMutedColor(theme)
                : adminBodyColor(theme),
            fontSize: AppFontSizes.size12,
            height: AppTextHeights.line1_8,
            fontStyle: body == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = reviewProductCategory(review);
    return _InfoCard(
      title: S.reviewsDetailsProduct,
      child: Row(
        children: [
          AdminNetworkThumb(imageUrl: review.product.imageUrl, size: 44),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewProductName(review),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(height: AppSizes.px2),
                Text(
                  [
                    ?category,
                    if (review.product.sku != null)
                      S.reviewsSku(review.product.sku!),
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
