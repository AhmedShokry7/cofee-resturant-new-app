import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_filter_scroll.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:flutter/material.dart';

/// خيار تصفية واحد: حرفٌ ترسله القاعدة، ولفظٌ يطبعه السطر.
class HrFilterChoice {
  const HrFilterChoice(this.value, this.label);

  final String value;
  final String label;
}

/// شريط تصفية بلفظ القاعدة وحرفها، و«الكل» يوازي `null`.
///
/// المطابقة بالموقع لا بالنص: لفظان اختلف حرفهما قد يتفقا في اللفظ بعد
/// الترجمة، و`null` هو وحده الذي يعني «لا قيد» فلا تُثقل القاعدة بقيد لا معنى
/// له. حرفٌ خارج القائمة (صفٌّ لم يُقرأ بعد) يُعرض كـ«الكل» لا كاختيار وهمي.
class HrValueSegment extends StatelessWidget {
  const HrValueSegment({
    super.key,
    required this.choices,
    required this.allLabel,
    required this.selected,
    required this.onChanged,
  });

  final List<HrFilterChoice> choices;
  final String allLabel;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[allLabel, for (final c in choices) c.label];
    final at = selected == null
        ? -1
        : choices.indexWhere((c) => c.value == selected);
    final current = at < 0 ? allLabel : labels[at + 1];
    return AdminSegmentedControl(
      options: labels,
      selected: current,
      onChanged: (label) {
        if (label == current) return;
        final index = labels.indexOf(label);
        onChanged(index <= 0 ? null : choices[index - 1].value);
      },
    );
  }
}

/// أشرطة التصفية في صفّ واحد يمرّ أفقيًا حين تضيق الشاشة.
class HrFilterStrip extends StatelessWidget {
  const HrFilterStrip({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HrFilterScroll(
    control: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          children[i],
        ],
      ],
    ),
  );
}
