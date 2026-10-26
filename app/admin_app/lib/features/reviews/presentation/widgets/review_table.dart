import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_actions_menu.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_badges.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_stars.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class ReviewTable extends StatelessWidget {
  const ReviewTable({
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

  static const _minWidth = 1220.0;
  static const _productWidth = 205.0;
  static const _customerWidth = 190.0;
  static const _purchaseWidth = 150.0;
  static const _dateWidth = 105.0;
  static const _statusWidth = 100.0;
  static const _actionWidth = 36.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, _minWidth), 1760)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final review in reviews)
                  _Row(
                    key: Key('review-row-${review.id}'),
                    review: review,
                    canManage: canManage,
                    onOpen: () => onOpen(review),
                    onToggle: () => onToggle(review),
                    onDelete: () => onDelete(review),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _cell(S.reviewsTableReview, dark)),
          SizedBox(
            width: ReviewTable._productWidth,
            child: _cell(S.reviewsTableProduct, dark),
          ),
          SizedBox(
            width: ReviewTable._customerWidth,
            child: _cell(S.reviewsTableCustomer, dark),
          ),
          SizedBox(
            width: ReviewTable._purchaseWidth,
            child: _cell(S.reviewsTablePurchase, dark),
          ),
          SizedBox(
            width: ReviewTable._dateWidth,
            child: _cell(S.reviewsTableDate, dark),
          ),
          SizedBox(
            width: ReviewTable._statusWidth,
            child: _cell(S.reviewsTableStatus, dark),
          ),
          const SizedBox(width: ReviewTable._actionWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, bool dark) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ReviewStars(rating: review.rating.toDouble(), size: 11),
                        const SizedBox(width: 6),
                        Text(
                          reviewAverageValue(review.rating.toDouble()),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size8_5,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reviewHeadline(review),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    if (excerpt != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        excerpt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminSubtleColor(theme),
                          fontSize: AppFontSizes.size9,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: ReviewTable._productWidth,
                child: Row(
                  children: [
                    AdminNetworkThumb(
                      imageUrl: review.product.imageUrl,
                      size: 34,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewProductName(review),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size10_5,
                              fontWeight: AppFontWeights.semiBold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            category ??
                                (review.product.sku == null
                                    ? '—'
                                    : S.reviewsSku(review.product.sku!)),
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
              ),
              SizedBox(
                width: ReviewTable._customerWidth,
                child: Row(
                  children: [
                    AdminAvatarImage(
                      url: review.customer.avatarUrl,
                      size: 28,
                      fallbackText: initial,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewCustomerName(review),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size10_5,
                              fontWeight: AppFontWeights.semiBold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            reviewCustomerDetail(review) ?? '—',
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
              ),
              SizedBox(
                width: ReviewTable._purchaseWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (review.isVerifiedPurchase)
                      const ReviewVerifiedChip(compact: true)
                    else
                      const ReviewUnverifiedLabel(),
                    const SizedBox(height: 3),
                    Text(
                      reviewOrderReference(review),
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
              SizedBox(
                width: ReviewTable._dateWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewDateLabel(review.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      reviewTimeLabel(review.createdAt),
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
              SizedBox(
                width: ReviewTable._statusWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ReviewStatusBadge(review: review),
                ),
              ),
              SizedBox(
                width: ReviewTable._actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ReviewActionsMenu(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
