import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_badges.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_stars.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

part 'review_details_rating_banner_meta_chip.dart';
part 'review_details_customer_card_purchase_card.dart';
part 'review_details_footer.dart';

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
        horizontal: screen.width < AppBreakpoints.pageCanvas
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RatingBanner(review: review),
                      const SizedBox(height: AppSizes.px16),
                      _ReviewContent(review: review),
                      const SizedBox(height: AppSizes.px18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final product = _ProductCard(review: review);
                          final customer = _CustomerCard(review: review);
                          if (constraints.maxWidth < 600) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                product,
                                const SizedBox(height: AppSizes.px10),
                                customer,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: product),
                              const SizedBox(width: AppSizes.px10),
                              Expanded(child: customer),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.px10),
                      _PurchaseCard(review: review),
                      const SizedBox(height: AppSizes.px14),
                      _MetaLine(
                        label: S.reviewsDetailsCreated,
                        value:
                            '${reviewDateLabel(review.createdAt)} • ${reviewTimeLabel(review.createdAt)}',
                      ),
                      if (review.updatedAt != null &&
                          review.updatedAt != review.createdAt) ...[
                        const SizedBox(height: AppSizes.px6),
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
