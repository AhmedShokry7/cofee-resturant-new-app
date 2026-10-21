import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// The small language box that starts the name row.
class RecordLanguageTag extends StatelessWidget {
  const RecordLanguageTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: AppDimensions.recordLanguageTagHeight,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      alignment: AlignmentDirectional.centerEnd,
      child: Text(label, style: theme.textTheme.bodyMedium),
    );
  }
}

/// The bordered label box that starts a row.
class RecordLabelBox extends StatelessWidget {
  const RecordLabelBox({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppDimensions.recordFieldLabelWidth,
      height: AppDimensions.recordFieldHeight,
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(AppDimensions.recordFieldRadius),
        ),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

/// The bordered currency box of the price row.
class RecordCurrencyBox extends StatelessWidget {
  const RecordCurrencyBox({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppDimensions.recordFieldValueWidth,
      height: AppDimensions.recordFieldHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(AppDimensions.recordFieldRadius),
        ),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(label, style: theme.textTheme.bodyMedium),
    );
  }
}

/// The bordered value box that fills the rest of a row.
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

    return Container(
      height: AppDimensions.recordFieldHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: 6,
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted ? AppColor.greyColor : null,
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

/// The narrow square action box on the trailing edge of a row.
class RecordActionBox extends StatelessWidget {
  const RecordActionBox({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.width = AppDimensions.recordFieldActionWidth,
    this.radiusEnd = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final double width;
  final bool radiusEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: AppDimensions.recordFieldHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radiusEnd
              ? const BorderRadius.horizontal(
                  right: Radius.circular(AppDimensions.recordFieldRadius),
                )
              : BorderRadius.zero,
          border: Border.all(color: theme.dividerColor),
        ),
        child: Icon(
          icon,
          size: 15,
          color: active ? AppColor.primaryColor : AppColor.greyColor,
        ),
      ),
    );
  }
}
