import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/builder_drag_feedback.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// مكتبة العناصر: كل ما يملك المحرّر إضافته إلى صفحة، مفرزًا بعائلته.
///
/// القائمة يملكها [WidgetRegistry] وحده، فلا عنصر هنا بلا رسم في `DesignRenderer`
/// ولا بلا بيانات يقراها. العنصر المقفول يُعرض ولا يُسحب: وجوده في التطبيق قرار
/// معماري، وإخفاؤه من المكتبة يوحي الموظف بأنه مفقود.
class WidgetLibraryPanel extends StatelessWidget {
  const WidgetLibraryPanel({
    super.key,
    required this.onAdd,
    required this.enabled,
  });

  /// إضافة بالنقر: تُوضع الطبقة في آخر الصفحة، وهو ما يفعله الإفلات حين لا موضع
  /// محدد بعد.
  final ValueChanged<String> onAdd;

  /// false في وضع المشاهدة وعلى الصفحات المقفولة: لا بناء، فتُعرض المكتبة صامتة.
  final bool enabled;

  AppLanguage get _language => AppLocale.instance.language;

  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[
      for (final category in WidgetCategory.values)
        if (WidgetRegistry.libraryOf(category).isNotEmpty)
          _family(context, category, WidgetRegistry.libraryOf(category)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(text: S.builderLibraryNote),
        const SizedBox(height: AppSpacing.md),
        for (final group in groups) ...[group, const SizedBox(height: AppSpacing.md)],
      ],
    );
  }

  Widget _family(
    BuildContext context,
    WidgetCategory category,
    List<WidgetSpec> specs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.builderFamily(category.name),
          style: TextStyle(
            color: adminSubtleColor(Theme.of(context)),
            fontSize: AppFontSizes.size10,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final spec in specs) ...[
          _LibraryCard(spec: spec, language: _language, enabled: enabled, onAdd: onAdd),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

/// بطاقة عنصر واحد: المقبض يُسحب، والبطاقة تُضغط فتُضاف.
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.spec,
    required this.language,
    required this.enabled,
    required this.onAdd,
  });

  final WidgetSpec spec;
  final AppLanguage language;
  final bool enabled;
  final ValueChanged<String> onAdd;

  bool get _draggable => enabled && spec.level != WidgetEditLevel.locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = spec.name.of(language);
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (_draggable)
            Draggable<BuilderDrag>(
              data: BuilderDrag(type: spec.type),
              feedback: BuilderDragFeedback(label: name),
              child: Icon(
                spec.icon,
                size: AppDimensions.iconSizeSm,
                color: adminMutedColor(theme),
              ),
            )
          else
            Icon(
              spec.icon,
              size: AppDimensions.iconSizeSm,
              color: adminSubtleColor(theme),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  spec.description.of(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.regular,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                if (spec.level != WidgetEditLevel.editable)
                  Text(
                    _levelLabel(),
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size9,
                      fontWeight: AppFontWeights.medium,
                      height: AppTextHeights.line1_3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: adminRowBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: theme.colorScheme.surface,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // النقر إضافة في آخر الصفحة: الإفلات يعطي الموضع، والنقر يعطي وجودًا.
        onTap: _draggable ? () => onAdd(spec.type) : null,
        child: body,
      ),
    );
  }

  String _levelLabel() => switch (spec.level) {
    WidgetEditLevel.partial => S.builderLevelPartial,
    WidgetEditLevel.locked => S.builderLevelLocked,
    WidgetEditLevel.editable => '',
  };
}

/// سطر شرح قصير أعلى اللوحة، بلون أهدأ من العناوين.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adminMutedColor(Theme.of(context)),
        fontSize: AppFontSizes.size10,
        fontWeight: AppFontWeights.regular,
        height: AppTextHeights.line1_5,
      ),
    );
  }
}
