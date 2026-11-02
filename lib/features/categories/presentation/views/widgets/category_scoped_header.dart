import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';

/// The line a page wears when it answers for one category only.
///
/// The row of tabs says "here are the others, pick one" - a page opened from a
/// banner has nothing to pick, so the category's own name takes that place and
/// the arrow is how the customer gets back to where the banner was pressed.
class CategoryScopedHeader extends StatelessWidget {
  const CategoryScopedHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: S.back,
            child: Material(
              color: AppColor.transparent,
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                onTap: onBack,
                child: SizedBox(
                  // The floor every target in the app keeps, on a glyph that is
                  // half that wide: an arrow missed is a customer stuck on a
                  // page with no other way out but the system gesture.
                  width: AppDimensions.tapTargetMin,
                  height: AppDimensions.tapTargetMin,
                  child: Center(
                    child: AppIcon(DirectionAwareIcons.back(context)),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.semiBold20(context),
            ),
          ),
        ],
      ),
    );
  }
}
