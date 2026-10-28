import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';

class OrderFilterDropdown extends StatelessWidget {
  const OrderFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  /// نص العنوان والقيمة المختارة. `value` قد تكون `null` حين لا قيمة مختارة،
  /// كما في قائمة أهداف الحالة حيث الحالة الحالية ليست هدفًا.
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? AppColor.darkBorder : AppColor.adminControlBorder;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      style: TextStyle(
        color: dark ? AppColor.darkText : AppColor.adminBody,
        fontSize: AppFontSizes.size11,
        height: AppTextHeights.line1_5,
      ),
      icon: AppIcon(AppIcons.arrowDown01, size: 16, color: muted),
      dropdownColor: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: muted,
          fontSize: AppFontSizes.size11,
          height: AppTextHeights.line1_5,
        ),
        floatingLabelStyle: TextStyle(
          color: dark ? AppColor.darkTextSecondary : AppColor.adminAccent,
          fontSize: AppFontSizes.size10_5,
          height: AppTextHeights.line1_5,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColor.adminAccent),
        ),
      ),
      items: items,
      onChanged: enabled
          ? (selected) {
              if (selected != null) onChanged(selected);
            }
          : null,
    );
  }
}
