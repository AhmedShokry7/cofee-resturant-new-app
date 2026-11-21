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

/// Inspector for the selected component. Editable controls come from that
/// component's registry entry; no generic placeholder controls are shown.
class VisualEditorRightInspector extends StatelessWidget {
  const VisualEditorRightInspector({
    super.key,
    required this.selectedComponent,
    required this.onPropertyChanged,
    required this.onResetProperty,
    this.onPropertiesChanged,
    required this.imagePermissions,
    this.onClose,
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
  final VoidCallback? onClose;
  final VoidCallback? onSaveDraft;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = VisualEditorTokens.border(context);

    return Container(
      width: VisualEditorTokens.inspectorWidth,
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        border: BorderDirectional(
          start: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: selectedComponent == null
          ? _buildEmptyState(context, dark)
          : _buildSelectedComponent(context, selectedComponent!, dark),
    );
  }

  Widget _buildSelectedComponent(
    BuildContext context,
    EditableComponent component,
    bool dark,
  ) {
    final entry = ComponentRegistry.get(component.componentType);
    final title = entry?.displayName ?? component.componentType;
    final textColor = VisualEditorTokens.text(context);
    final mutedColor = VisualEditorTokens.textMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: dark
                ? VisualEditorTokens.darkSurfaceSecondary
                : VisualEditorTokens.surfaceSoftCreamSecondary,
            border: Border(
              bottom: BorderSide(color: VisualEditorTokens.border(context)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.tune,
                size: 18,
                color: VisualEditorTokens.primaryOliveGreen,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.size12,
                        fontWeight: AppFontWeights.semiBold,
                        color: textColor,
                      ),
                    ),
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
                  icon: const Icon(Icons.close_rounded, size: 17),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: PropertiesInspectorPanel(
            key: ValueKey(component.componentId),
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
        if (onSaveDraft != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: FilledButton.icon(
              onPressed: isDirty ? onSaveDraft : null,
              icon: const Icon(Icons.save_outlined, size: 17),
              label: Text(S.visualEditorSaveDraft),
              style: FilledButton.styleFrom(
                backgroundColor: VisualEditorTokens.primaryOliveGreen,
                disabledBackgroundColor: VisualEditorTokens.primaryOliveGreen
                    .withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                alignment: AlignmentDirectional.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: dark
                  ? VisualEditorTokens.darkSurfaceSecondary
                  : VisualEditorTokens.surfaceSoftCreamSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: VisualEditorTokens.border(context)),
            ),
            child: const Icon(
              Icons.touch_app_outlined,
              size: 25,
              color: VisualEditorTokens.primaryOliveGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            S.visualEditorNoSelection,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.bold,
              color: VisualEditorTokens.text(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            S.visualEditorSelectHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: VisualEditorTokens.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
