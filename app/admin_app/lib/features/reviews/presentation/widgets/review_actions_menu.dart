import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum ReviewAction { details, togglePublished, delete }

class ReviewActionsMenu extends StatelessWidget {
  const ReviewActionsMenu({
    super.key,
    required this.review,
    required this.canManage,
    required this.onAction,
  });

  final AdminReview review;
  final bool canManage;
  final ValueChanged<ReviewAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopupMenuButton<ReviewAction>(
      key: Key('review-menu-${review.id}'),
      tooltip: S.reviewsMenuTooltip,
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem<ReviewAction>(
          value: ReviewAction.details,
          child: _item(
            theme,
            icon: HugeIcons.strokeRoundedEye,
            label: S.reviewsViewDetails,
            direction: rtl,
          ),
        ),
        if (canManage) ...[
          PopupMenuItem<ReviewAction>(
            value: ReviewAction.togglePublished,
            child: _item(
              theme,
              icon: review.isPublished
                  ? HugeIcons.strokeRoundedViewOff
                  : HugeIcons.strokeRoundedCheckmarkCircle02,
              label: review.isPublished ? S.reviewsHide : S.reviewsPublish,
              direction: rtl,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<ReviewAction>(
            value: ReviewAction.delete,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedDelete02,
              label: S.reviewsDelete,
              direction: rtl,
              color: AppColor.errorColor,
            ),
          ),
        ],
      ],
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        size: 18,
        color: adminMutedColor(theme),
      ),
    );
  }

  Widget _item(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool direction,
    Color? color,
  }) => Row(
    textDirection: direction ? TextDirection.rtl : TextDirection.ltr,
    children: [
      HugeIcon(icon: icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: color ?? adminBodyColor(theme),
          fontSize: AppFontSizes.size11,
          height: AppTextHeights.line1_5,
        ),
      ),
    ],
  );
}
