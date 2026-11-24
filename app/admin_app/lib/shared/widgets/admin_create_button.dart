import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// A primary action button for adding or creating an Admin record.
///
/// Its compact geometry, label spacing, typography, and ink response match the
/// Admin toolbar actions, while the primary fill keeps create actions prominent.
class AdminCreateButton extends StatelessWidget {
  const AdminCreateButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon = AppIcons.add01,
    this.busy = false,
    this.iconOnly = false,
    this.tooltip,
  }) : assert(iconOnly || label != null),
       assert(!iconOnly || tooltip != null);

  final String? label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool iconOnly;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final borderRadius = BorderRadius.circular(AppRadius.md);
    final content = iconOnly
        ? SizedBox.square(
            dimension: AppSizes.px38,
            child: Center(
              child: AppIcon(
                icon ?? AppIcons.add01,
                size: AppSizes.px16,
                color: AppColor.whiteColor,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColor.whiteColor,
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                if (busy) ...[
                  const SizedBox(width: AppSizes.px10),
                  const SizedBox(
                    width: AppSizes.px16,
                    height: AppSizes.px16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColor.whiteColor,
                    ),
                  ),
                ] else if (icon != null) ...[
                  const SizedBox(width: AppSizes.px10),
                  AppIcon(icon!, size: AppSizes.px16, color: AppColor.whiteColor),
                ],
              ],
            ),
          );

    final button = Opacity(
      opacity: !enabled && !busy ? .5 : 1,
      child: Material(
        color: AppColor.primaryColor,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: borderRadius,
          splashColor: AppColor.whiteColor.withValues(alpha: .14),
          hoverColor: AppColor.whiteColor.withValues(alpha: .08),
          focusColor: AppColor.whiteColor.withValues(alpha: .12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColor.primaryColor),
              borderRadius: borderRadius,
            ),
            child: content,
          ),
        ),
      ),
    );

    final help = tooltip ?? label;
    return help == null ? button : Tooltip(message: help, child: button);
  }
}
