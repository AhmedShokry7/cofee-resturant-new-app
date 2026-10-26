import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// Header shared by the admin editor dialogs.
class AdminDialogHeader extends StatelessWidget {
  const AdminDialogHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size16,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9_5,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.close,
            onPressed: onClose,
            style: IconButton.styleFrom(
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.cancel01,
              size: 18,
              color: adminMutedColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer with the cancel/save pair shared by the admin editor dialogs.
class AdminDialogFooter extends StatelessWidget {
  const AdminDialogFooter({
    super.key,
    required this.saving,
    required this.onCancel,
    required this.onSave,
    required this.saveKey,
    required this.saveLabel,
    required this.savingLabel,
    this.cancelLabel,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final Key saveKey;
  final String saveLabel;
  final String savingLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
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
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text(cancelLabel ?? S.cancel),
          ),
          FilledButton(
            key: saveKey,
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (saving) ...[
                  const SizedBox(
                    width: AppSizes.px14,
                    height: AppSizes.px14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColor.whiteColor,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                ],
                Text(
                  saving ? savingLabel : saveLabel,
                  style: const TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.semiBold,
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

/// The compact text-field decoration shared by the admin editor dialogs.
InputDecoration adminDialogFieldDecoration(
  BuildContext context, {
  required String label,
  required String hint,
  bool required = false,
}) {
  final theme = Theme.of(context);
  final border = adminControlBorderColor(theme);
  final radius = BorderRadius.circular(AppRadius.md);
  return InputDecoration(
    labelText: required ? '$label *' : label,
    hintText: hint,
    counterText: '',
    isDense: true,
    labelStyle: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10_5,
    ),
    floatingLabelStyle: const TextStyle(
      color: AppColor.adminAccent,
      fontSize: AppFontSizes.size10_5,
      fontWeight: AppFontWeights.semiBold,
    ),
    hintStyle: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10_5,
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColor.adminAccent),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border.withValues(alpha: .5)),
    ),
  );
}

class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.errorColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.errorColor.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(AppIcons.alert, size: 16, color: AppColor.errorColor),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColor.errorColor,
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
