import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_actions_menu.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_badges.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_stars.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class ReviewCards extends StatelessWidget {
  const ReviewCards({
    super.key,
    required this.reviews,
    required this.canManage,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminReview> reviews;
  final bool canManage;
  final ValueChanged<AdminReview> onOpen;
  final ValueChanged<AdminReview> onToggle;
  final ValueChanged<AdminReview> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return _ReviewCard(
          key: Key('review-card-${review.id}'),
          review: review,
          canManage: canManage,
          onOpen: () => onOpen(review),
          onToggle: () => onToggle(review),
          onDelete: () => onDelete(review),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.review,
    required this.canManage,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminReview review;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final excerpt = reviewExcerpt(review);
    final category = reviewProductCategory(review);
    final initial = reviewCustomerInitial(review);
    final customerDetail = reviewCustomerDetail(review);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ReviewStars(
                    rating: review.rating.toDouble(),
                    size: 13,
                    showValue: true,
                  ),
                  const Spacer(),
                  ReviewStatusBadge(review: review),
                  const SizedBox(width: 4),
                  ReviewActionsMenu(
                    review: review,
                    canManage: canManage,
                    onAction: (action) {
                      switch (action) {
                        case ReviewAction.details:
                          onOpen();
                        case ReviewAction.togglePublished:
                          onToggle();
                        case ReviewAction.delete:
                          onDelete();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                reviewHeadline(review),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminBodyColor(theme),
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_5,
                ),
              ),
              if (excerpt != null) ...[
                const SizedBox(height: 2),
                Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_55,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Divider(height: 1, color: adminRowBorderColor(theme)),
              const SizedBox(height: 9),
              _ContextRow(
                leading: AdminNetworkThumb(
                  imageUrl: review.product.imageUrl,
                  size: 30,
                ),
                title: reviewProductName(review),
                detail:
                    category ??
                    (review.product.sku == null
                        ? S.reviewsTableProduct
                        : S.reviewsSku(review.product.sku!)),
              ),
              const SizedBox(height: 8),
              _ContextRow(
                leading: AdminAvatarImage(
                  url: review.customer.avatarUrl,
                  size: 26,
                  fallbackText: initial,
                ),
                title: reviewCustomerName(review),
                detail: customerDetail,
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (review.isVerifiedPurchase)
                    const ReviewVerifiedChip(compact: true)
                  else
                    const ReviewUnverifiedLabel(),
                  _Meta(
                    icon: HugeIcons.strokeRoundedInvoice01,
                    label: reviewOrderReference(review),
                  ),
                  _Meta(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    label: reviewDateLabel(review.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.leading, required this.title, this.detail});

  final Widget leading;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminBodyColor(theme),
                  fontSize: AppFontSizes.size10,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
              if (detail != null && detail!.isNotEmpty)
                Text(
                  detail!,
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
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 11, color: adminMutedColor(theme)),
        const SizedBox(width: 4),
        Text(
          label,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size8_5,
            height: AppTextHeights.line1_4,
          ),
        ),
      ],
    );
  }
}
