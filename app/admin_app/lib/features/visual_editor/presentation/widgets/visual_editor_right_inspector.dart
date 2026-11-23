import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_image_asset_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';

/// مفتش الخصائص للمكوّن المحدد. عناصر التحرير تأتي من سجلّ ذلك المكوّن؛
/// لا تُعرض أي عناصر تحكم عامة وهمية.
class VisualEditorRightInspector extends StatelessWidget {
  const VisualEditorRightInspector({
    super.key,
    required this.selectedComponent,
    required this.onPropertyChanged,
    required this.onResetProperty,
    this.onPropertiesChanged,
    required this.imagePermissions,
    this.onClose,
    this.splashGroup,
    this.onSaveDraft,
    this.isDirty = false,
  });

  final EditableComponent? selectedComponent;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  })
  onPropertyChanged;
  final void Function({
    required String componentId,
    required String propertyKey,
  })
  onResetProperty;
  final void Function({
    required String componentId,
    required Map<String, dynamic> values,
  })?
  onPropertiesChanged;
  final Set<String> imagePermissions;
  final String? splashGroup;
  final VoidCallback? onClose;
  final VoidCallback? onSaveDraft;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPanel),
        border: Border.all(color: VisualEditorTokens.border(context)),
        boxShadow: VisualEditorTokens.panelShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPanel),
        child: selectedComponent == null
            ? _buildEmptyState(context)
            : _buildSelectedComponent(context, selectedComponent!),
      ),
    );
  }

  Widget _buildSelectedComponent(
    BuildContext context,
    EditableComponent component,
  ) {
    final entry = ComponentRegistry.get(component.componentType);
    final title = component.componentType == 'splashSettings'
        ? S.visualEditorSplashImage
        : entry?.displayName ?? component.componentType;
    final textColor = VisualEditorTokens.text(context);
    final mutedColor = VisualEditorTokens.textMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ——— ترويسة المفتش ———
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: VisualEditorTokens.surfaceSecondary(context),
            border: Border(
              bottom: BorderSide(color: VisualEditorTokens.border(context)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: VisualEditorTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: VisualEditorTokens.primaryOliveGreen.withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _iconForComponent(component.componentType),
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFontSizes.size12_5,
                              fontWeight: AppFontWeights.semiBold,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: VisualEditorTokens.surfaceSecondary(context),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: VisualEditorTokens.border(context),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            component.componentType,
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      component.componentId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.size9_5,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  tooltip: 'إغلاق',
                  icon: Icon(Icons.close_rounded, size: 17, color: mutedColor),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        // ——— عناصر التحرير ———
        Expanded(
          child: PropertiesInspectorPanel(
            key: ValueKey((component.componentId, splashGroup)),
            splashGroup: splashGroup,
            component: component,
            showHeader: false,
            onPropertyChanged: onPropertyChanged,
            onResetProperty: onResetProperty,
            onPropertiesChanged: onPropertiesChanged,
            onBrowseImages: () => showVisualEditorImageAssetPicker(
              context: context,
              repository: VisualEditorImageAssetRepository(),
              permissions: imagePermissions,
            ),
          ),
        ),
        // ——— زر حفظ المسودة (اختياري) ———
        if (onSaveDraft != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: VisualEditorTokens.border(context)),
              ),
            ),
            child: FilledButton.icon(
              onPressed: isDirty ? onSaveDraft : null,
              icon: const Icon(Icons.save_outlined, size: 17),
              label: Text(S.visualEditorSaveDraft),
              style: FilledButton.styleFrom(
                backgroundColor: VisualEditorTokens.primaryOliveGreen,
                disabledBackgroundColor: VisualEditorTokens.primaryOliveGreen
                    .withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusMd,
                  ),
                ),
                alignment: AlignmentDirectional.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الترويسة تبقى ثابتة حتى بلا تحديد فتبدو اللوحة جزءًا كاملًا
        // من الاستوديو لا لوحة فارغة مكسورة.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: VisualEditorTokens.surfaceSecondary(context),
            border: Border(
              bottom: BorderSide(color: VisualEditorTokens.border(context)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: VisualEditorTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: VisualEditorTokens.primaryOliveGreen.withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(AppIcons.tune, size: 16, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  S.visualEditorProperties,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.semiBold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  tooltip: 'إغلاق',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: VisualEditorTokens.accentSurface(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: VisualEditorTokens.accentBorder(context),
                    ),
                  ),
                  child: const Icon(
                    Icons.touch_app_outlined,
                    size: 30,
                    color: VisualEditorTokens.primaryOliveGreen,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  S.visualEditorNoSelection,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: AppFontWeights.bold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  S.visualEditorSelectHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForComponent(String type) => switch (type) {
    'header' => AppIcons.menu01,
    'searchBar' => Icons.search,
    'bannerCarousel' => Icons.view_carousel_outlined,
    'promoBanner' => Icons.campaign_outlined,
    'categoryList' => Icons.category_outlined,
    'productStrip' => Icons.view_week_outlined,
    'productGrid' => Icons.grid_on_outlined,
    'bundleList' => Icons.inventory_2_outlined,
    'heading' => Icons.title,
    'text' => Icons.text_fields,
    'image' => Icons.image_outlined,
    'divider' => Icons.horizontal_rule,
    'spacer' => Icons.space_bar,
    'column' => Icons.view_column_outlined,
    'row' => Icons.table_rows_outlined,
    'button' => Icons.smart_button_outlined,
    'nativeLabel' => Icons.label_outline,
    'splashSettings' => Icons.tv_rounded,
    'welcomeHero' => Icons.photo_size_select_actual_outlined,
    'welcomeTitle' => Icons.title,
    'welcomeBody' => Icons.text_fields,
    'welcomeSpacing' => Icons.space_bar,
    'welcomeCta' => Icons.smart_button_outlined,
    _ => Icons.tune_rounded,
  };
}
