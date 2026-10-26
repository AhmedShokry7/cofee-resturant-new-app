part of 'review_details_dialog.dart';

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = reviewCustomerDetail(review);
    return _InfoCard(
      title: S.reviewsDetailsCustomer,
      child: Row(
        children: [
          AdminAvatarImage(
            url: review.customer.avatarUrl,
            size: 40,
            fallbackText: reviewCustomerInitial(review),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewCustomerName(review),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                if (review.customer.phone != null)
                  Text(
                    review.customer.phone!,
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

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InfoCard(
      title: S.reviewsDetailsPurchase,
      child: review.isVerifiedPurchase
          ? Row(
              children: [
                const ReviewVerifiedChip(),
                const Spacer(),
                Flexible(
                  child: Text(
                    reviewOrderReference(review),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size10_5,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              S.reviewsDetailsNoOrder,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_5,
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label: title),
          const SizedBox(height: AppSizes.px8),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        color: adminMutedColor(theme),
        fontSize: AppFontSizes.size8_5,
        fontWeight: AppFontWeights.semiBold,
        height: AppTextHeights.line1_4,
        letterSpacing: AppLetterSpacings.space0_2,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_4,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
      ],
    );
  }
}
