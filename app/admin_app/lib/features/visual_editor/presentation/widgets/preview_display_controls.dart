import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';

/// أدوات لغة ووضع تطبيق العميل داخل المعاينة فقط.
///
/// هذه ليست لغة لوحة الأدمن ولا مظهرها: زر اللغة يغيّر ما تقرأه المعاينة
/// بالعربية/الإنجليزية، وزر المظهر يغيّرها بين فاتح وداكن. الاختياران يعيشان
/// في حالة المحرّر، فيُرسلان مع كل مستند ومع رابط الإطار عند إعادة تحميله،
/// ولا يكتبان أي تفضيل في تطبيق العميل ولا في المسودة المنشورة.
class PreviewDisplayControls extends StatelessWidget {
  const PreviewDisplayControls({
    super.key,
    required this.state,
    required this.cubit,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewChip(
          tooltip: S.visualEditorPreviewLanguage,
          icon: AppIcons.translate,
          label: state.previewLanguage.code,
          onTap: cubit.togglePreviewLanguage,
          dark: dark,
        ),
        const SizedBox(width: AppSpacing.xs),
        _PreviewChip(
          tooltip: S.visualEditorPreviewTheme,
          icon: state.previewThemeMode == PreviewThemeMode.dark
              ? AppIcons.moon01
              : AppIcons.sun03,
          onTap: cubit.togglePreviewThemeMode,
          dark: dark,
        ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.dark,
    this.label,
  });

  final String tooltip;
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final muted = VisualEditorTokens.textMuted(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusXl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
            decoration: BoxDecoration(
              color: dark
                  ? VisualEditorTokens.darkSurfaceSecondary
                  : VisualEditorTokens.surfaceSoftCreamSecondary,
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusXl),
              border: Border.all(
                color: VisualEditorTokens.border(context),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: muted),
                if (label != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: AppFontWeights.bold,
                      color: VisualEditorTokens.text(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
