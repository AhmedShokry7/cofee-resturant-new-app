import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// Option shown to a manager and sent to the HR API.
class HrFilterChoice {
  const HrFilterChoice(this.value, this.label);

  final String value;
  final String label;
}

/// Compact filter selector shared by HR lists.
///
/// A dropdown keeps filters usable when a branch or employee list grows. The
/// selected value remains the API value; labels are presentation only.
class HrValueSegment extends StatelessWidget {
  const HrValueSegment({
    super.key,
    required this.choices,
    required this.allLabel,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final List<HrFilterChoice> choices;
  final String allLabel;
  final String label;
  final String? selected;
  final ValueChanged<String?> onChanged;

  static const String _all = '\u0000hr_all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(value: _all, child: Text(allLabel)),
      for (final choice in choices)
        DropdownMenuItem<String>(
          value: choice.value,
          child: Text(
            choice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final value = choices.any((choice) => choice.value == selected)
        ? selected!
        : _all;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 240),
      child: InputDecorator(
        isFocused: false,
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
          contentPadding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            end: AppSpacing.xs,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: adminControlBorderColor(theme)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: adminControlBorderColor(theme)),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size12,
              height: AppTextHeights.line1_5,
            ),
            items: options,
            onChanged: (next) =>
                onChanged(next == null || next == _all ? null : next),
          ),
        ),
      ),
    );
  }
}

/// Filters wrap into tidy rows on narrow screens instead of forming a long
/// horizontal strip that hides the selected option off-screen.
class HrFilterStrip extends StatelessWidget {
  const HrFilterStrip({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: children,
  );
}
