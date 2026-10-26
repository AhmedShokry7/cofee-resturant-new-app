import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';

/// The compact search box shared by the admin directories.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final border = dark ? AppColor.darkBorder : AppColor.adminControlBorder;
    final radius = BorderRadius.circular(AppRadius.md);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => SizedBox(
        height: AppSizes.px38,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            color: dark ? AppColor.darkText : AppColor.adminBody,
            fontSize: AppFontSizes.size11,
            height: AppTextHeights.line1_5,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: muted,
              fontSize: AppFontSizes.size11,
              height: AppTextHeights.line1_5,
            ),
            prefixIcon: AppIcon(AppIcons.search01, size: 16, color: muted),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 34,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: S.clearSearch,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: AppIcon(AppIcons.cancel01, size: 14, color: muted),
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            filled: true,
            fillColor: theme.colorScheme.surface,
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
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminToolbarButton extends StatelessWidget {
  const AdminToolbarButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.busy = false,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool active;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null && !busy && !active ? .5 : 1,
    child: Material(
      color: AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AdminToolbarSurface(
          label: label,
          icon: icon,
          busy: busy,
          active: active,
        ),
      ),
    ),
  );
}

class AdminToolbarIcon extends StatelessWidget {
  const AdminToolbarIcon({super.key, required this.icon, this.active = false});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = _foreground(dark, active);
    return Container(
      width: 37,
      height: 37,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _background(theme, active),
        border: Border.all(
          color: active
              ? AppColor.adminAccent.withValues(alpha: .45)
              : (dark ? AppColor.darkBorder : AppColor.adminControlBorder),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AppIcon(icon, size: 16, color: foreground),
    );
  }
}

class AdminToolbarSurface extends StatelessWidget {
  const AdminToolbarSurface({
    super.key,
    required this.label,
    required this.icon,
    this.active = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = _foreground(dark, active);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _background(theme, active),
        border: Border.all(
          color: active
              ? AppColor.adminAccent.withValues(alpha: .45)
              : (dark ? AppColor.darkBorder : AppColor.adminControlBorder),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          if (busy)
            SizedBox(
              width: AppSizes.px16,
              height: AppSizes.px16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          else
            AppIcon(icon, size: 16, color: foreground),
        ],
      ),
    );
  }
}

Color _foreground(bool dark, bool active) => active
    ? AppColor.adminAccent
    : dark
    ? AppColor.darkTextSecondary
    : AppColor.adminBody;

Color _background(ThemeData theme, bool active) {
  if (!active) return theme.colorScheme.surface;
  return theme.brightness == Brightness.dark
      ? AppColor.adminAccent.withValues(alpha: .18)
      : AppColor.adminAccentSurface;
}
