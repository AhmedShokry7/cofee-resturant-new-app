import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';

Color _cellBackground(bool dark) =>
    dark ? AppColor.darkSurfaceContainer : AppColor.recordCellBackground;

Color _fieldBorder(bool dark) =>
    dark ? AppColor.darkBorder : AppColor.recordBorder;

Color _strongText(bool dark) =>
    dark ? AppColor.darkText : AppColor.recordTextStrong;

Color _labelText(bool dark) =>
    dark ? AppColor.darkTextSecondary : AppColor.recordText;

Color _mutedText(bool dark) =>
    dark ? AppColor.darkTextSecondary : AppColor.recordTextMuted;

Color _actionText(bool dark) =>
    dark ? AppColor.secondaryColor : AppColor.primaryColor;

/// Label cell matching the light-grey Figma field styling.
class RecordLabelBox extends StatelessWidget {
  const RecordLabelBox({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: AppDimensions.recordFieldLabelWidth,
      height: AppDimensions.recordFieldHeight,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: _cellBackground(dark),
        border: Border.all(color: _fieldBorder(dark)),
        borderRadius: const BorderRadiusDirectional.horizontal(
          start: Radius.circular(AppDimensions.recordFieldRadius),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: _labelText(dark),
          fontSize: AppFontSizes.size12,
        ),
      ),
    );
  }
}

/// Value cell that expands to use the available row width.
class RecordValueBox extends StatelessWidget {
  const RecordValueBox({
    super.key,
    required this.value,
    required this.alignEnd,
    this.trailing,
    this.muted = false,
  });

  final String value;
  final bool alignEnd;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 0),
      height: AppDimensions.recordFieldHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: _fieldBorder(dark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
              child: Align(
                alignment: alignEnd
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted ? _mutedText(dark) : _strongText(dark),
                    fontSize: AppFontSizes.size12,
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A value cell the admin can type in.
///
/// It keeps the shape of the other cells of the record card, so an editable
/// row still reads like a table row.
class RecordTextFieldBox extends StatelessWidget {
  const RecordTextFieldBox({
    super.key,
    required this.controller,
    this.hint,
    this.inputFormatters,
    this.textInputType,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String? hint;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? textInputType;
  final TextAlign textAlign;

  /// False for a card that cannot be written: the field shows the value but
  /// refuses the edit, so no reader types a change the database would reject.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 0),
      height: AppDimensions.recordFieldHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: _fieldBorder(dark)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
        child: Center(
          child: TextField(
            controller: controller,
            textAlign: textAlign,
            keyboardType: textInputType,
            inputFormatters: inputFormatters,
            readOnly: readOnly,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _strongText(dark),
              fontSize: AppFontSizes.size12,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                color: _mutedText(dark),
                fontSize: AppFontSizes.size12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A value cell that opens a picker, such as the category of a product.
class RecordSelectBox extends StatelessWidget {
  const RecordSelectBox({
    super.key,
    required this.value,
    this.onTap,
    this.muted = false,
  });

  final String value;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 0),
          height: AppDimensions.recordFieldHeight,
          decoration: BoxDecoration(
            border: Border.all(color: _fieldBorder(dark)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted ? _mutedText(dark) : _strongText(dark),
                      fontSize: AppFontSizes.size12,
                    ),
                  ),
                ),
              ),
              Icon(
                AppIcons.arrowDown01,
                size: 13,
                color: dark ? AppColor.darkTextSecondary : AppColor.greyColor,
              ),
              const SizedBox(width: AppSizes.px8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square action cell on the edge of a row.
///
/// It shows an icon by default; pass a [child] instead to place any other
/// mark, such as the Saudi Riyal symbol, in the same cell.
class RecordActionBox extends StatelessWidget {
  const RecordActionBox({
    super.key,
    this.icon,
    this.child,
    this.onTap,
    this.active = false,
    this.width = AppDimensions.recordFieldActionWidth,
    this.radiusEnd = false,
    this.radiusStart = false,
  });

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final bool active;
  final double width;
  final bool radiusEnd;
  final bool radiusStart;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: _cellBackground(dark),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: width,
          height: AppDimensions.recordFieldHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: _fieldBorder(dark)),
            borderRadius: BorderRadiusDirectional.horizontal(
              start: radiusStart
                  ? const Radius.circular(AppDimensions.recordFieldRadius)
                  : Radius.zero,
              end: radiusEnd
                  ? const Radius.circular(AppDimensions.recordFieldRadius)
                  : Radius.zero,
            ),
          ),
          child:
              child ??
              Icon(
                icon,
                size: 15,
                color: active
                    ? _actionText(dark)
                    : (dark ? AppColor.darkTextSecondary : AppColor.greyColor),
              ),
        ),
      ),
    );
  }
}

/// Grey action cell that shows an icon next to a label.
///
/// It carries the actions that need a word to be clear, such as adding a
/// category to the product.
class RecordActionLabelBox extends StatelessWidget {
  const RecordActionLabelBox({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.radiusEnd = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool radiusEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = _actionText(dark);
    return Material(
      color: _cellBackground(dark),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: AppDimensions.recordFieldHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: _fieldBorder(dark)),
            borderRadius: BorderRadiusDirectional.horizontal(
              end: radiusEnd
                  ? const Radius.circular(AppDimensions.recordFieldRadius)
                  : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: AppSizes.px6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
