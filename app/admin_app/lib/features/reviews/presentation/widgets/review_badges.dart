import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class ReviewStatusBadge extends StatelessWidget {
  const ReviewStatusBadge({super.key, required this.review});

  final AdminReview review;

  @override
  Widget build(BuildContext context) => AdminStatusBadge(
    label: reviewStatusName(review),
    color: reviewStatusColor(review),
  );
}

class ReviewVerifiedChip extends StatelessWidget {
  const ReviewVerifiedChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = adminFlagForeground(theme, AppColor.adminInfo);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminInfo,
          AppColor.adminInfoSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColor.adminInfo.withValues(
            alpha: adminIsDark(theme) ? .35 : .18,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.checkmarkBadge02,
              size: compact ? 11 : 12,
              color: color,
            ),
            const SizedBox(width: AppSizes.px4),
            Text(
              S.reviewsVerified,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewUnverifiedLabel extends StatelessWidget {
  const ReviewUnverifiedLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.circle, size: 11, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px4),
          Text(
            S.reviewsUnverified,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}
