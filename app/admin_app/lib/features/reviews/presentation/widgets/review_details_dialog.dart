import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_badges.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_stars.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum ReviewDetailsAction { togglePublished, delete }

Future<ReviewDetailsAction?> showReviewDetailsDialog({
  required BuildContext context,
  required AdminReview review,
  required bool canManage,
}) {
  return showDialog<ReviewDetailsAction>(
    context: context,
    builder: (_) => ReviewDetailsDialog(review: review, canManage: canManage),
  );
}

class ReviewDetailsDialog extends StatelessWidget {
  const ReviewDetailsDialog({
    super.key,
    required this.review,
    required this.canManage,
  });

  final AdminReview review;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .86, 760.0);
    return Dialog(
      key: const Key('review-details-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 700 ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: S.reviewsDetailsTitle,
                subtitle: S.reviewsDetailsSubtitle(reviewProductName(review)),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RatingBanner(review: review),
                      const SizedBox(height: 16),
                      _ReviewContent(review: review),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final product = _ProductCard(review: review);
                          final customer = _CustomerCard(review: review);
                          if (constraints.maxWidth < 600) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                product,
                                const SizedBox(height: 10),
                                customer,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: product),
                              const SizedBox(width: 10),
                              Expanded(child: customer),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _PurchaseCard(review: review),
                      const SizedBox(height: 14),
                      _MetaLine(
                        label: S.reviewsDetailsCreated,
                        value:
                            '${reviewDateLabel(review.createdAt)} • ${reviewTimeLabel(review.createdAt)}',
                      ),
                      if (review.updatedAt != null &&
                          review.updatedAt != review.createdAt) ...[
                        const SizedBox(height: 5),
                        _MetaLine(
                          label: S.reviewsDetailsUpdated,
                          value:
                              '${reviewDateLabel(review.updatedAt)} • ${reviewTimeLabel(review.updatedAt)}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Footer(review: review, canManage: canManage),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingBanner extends StatelessWidget {
  const _RatingBanner({required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 8),
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
                icon: HugeIcons.strokeRoundedCalendar03,
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
        HugeIcon(icon: icon, size: 12, color: adminMutedColor(theme)),
        const SizedBox(width: 4),
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
        const SizedBox(height: 5),
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
        if (title != null) const SizedBox(height: 5),
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
          const SizedBox(width: 10),
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
                const SizedBox(height: 2),
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
          const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label: title),
          const SizedBox(height: 8),
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
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.sm,
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
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: HugeIcon(
                icon: review.isPublished
                    ? HugeIcons.strokeRoundedViewOff
                    : HugeIcons.strokeRoundedCheckmarkCircle02,
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
