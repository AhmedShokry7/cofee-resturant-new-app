import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';

/// لوحة شجرة المكوّنات — تعرض المكوّنات المسجلة في الصفحة المحددة
/// وتتيح تحديدها وإعادة ترتيبها وإخفاءها وحذفها.
class ComponentTreePanel extends StatelessWidget {
  const ComponentTreePanel({
    super.key,
    required this.pageId,
    required this.components,
    required this.selectedComponentId,
    required this.onSelect,
    required this.onReorder,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleVisibility,
  });

  final String pageId;
  final List<EditableComponent> components;
  final String? selectedComponentId;
  final void Function(String componentId) onSelect;
  final void Function(String componentId, int newIndex) onReorder;
  final void Function(String componentId) onDelete;
  final void Function(String componentId) onDuplicate;
  final void Function(String componentId) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurface : AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: AppIcons.layers01,
            title: S.visualEditorLayers,
          ),
          const Divider(height: 1),
          Expanded(
            child: components.isEmpty
                ? AdminEmptyState(
                    icon: AppIcons.layers01,
                    message: S.visualEditorNoComponents,
                  )
                : _ComponentList(
                    components: components,
                    selectedComponentId: selectedComponentId,
                    onSelect: onSelect,
                    onReorder: onReorder,
                    onDelete: onDelete,
                    onDuplicate: onDuplicate,
                    onToggleVisibility: onToggleVisibility,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComponentList extends StatelessWidget {
  const _ComponentList({
    required this.components,
    required this.selectedComponentId,
    required this.onSelect,
    required this.onReorder,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleVisibility,
  });

  final List<EditableComponent> components;
  final String? selectedComponentId;
  final void Function(String) onSelect;
  final void Function(String, int) onReorder;
  final void Function(String) onDelete;
  final void Function(String) onDuplicate;
  final void Function(String) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: components.length,
      onReorderItem: (oldIndex, newIndex) {
        final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
        onReorder(components[oldIndex].componentId, adjusted);
      },
      itemBuilder: (context, index) {
        final component = components[index];
        return _ComponentRow(
          key: ValueKey(component.componentId),
          component: component,
          isSelected: component.componentId == selectedComponentId,
          onTap: () => onSelect(component.componentId),
          onDelete: component.canDelete
              ? () => onDelete(component.componentId)
              : null,
          onDuplicate: component.canDuplicate
              ? () => onDuplicate(component.componentId)
              : null,
          onToggleVisibility: () =>
              onToggleVisibility(component.componentId),
        );
      },
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    super.key,
    required this.component,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onDuplicate,
    required this.onToggleVisibility,
  });

  final EditableComponent component;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isVisible = component.properties['visible'] as bool? ?? true;
    final entry = ComponentRegistry.get(component.componentType);

    final selectedBg = dark ? AppColor.darkSurfaceContainer : AppColor.adminAccentSurface;
    final rowBg = isSelected ? selectedBg : Colors.transparent;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final bodyColor = dark ? AppColor.darkText : AppColor.adminBody;

    return Material(
      color: rowBg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              // Drag handle — يظهر فقط للمكوّنات القابلة لإعادة الترتيب
              if (component.canReorder)
                ReorderableDragStartListener(
                  index: component.index,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                    child: Icon(Icons.drag_indicator, size: 16, color: muted),
                  ),
                )
              else
                SizedBox(width: AppSpacing.lg + AppSpacing.xs),

              // أيقونة النوع
              Icon(
                _iconForType(component.componentType),
                size: AppDimensions.iconSizeSm,
                color: isSelected ? accent : muted,
              ),
              const SizedBox(width: AppSpacing.sm),

              // الاسم
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry?.displayName ?? component.componentType,
                      style: TextStyle(
                        fontSize: AppFontSizes.size12,
                        fontWeight: isSelected
                            ? AppFontWeights.semiBold
                            : AppFontWeights.regular,
                        color: bodyColor,
                        height: AppTextHeights.line1_4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      component.componentId,
                      style: TextStyle(
                        fontSize: AppFontSizes.size9_5,
                        color: muted,
                        height: AppTextHeights.line1_3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // أزرار الإجراءات
              _ActionButton(
                icon: isVisible ? AppIcons.eyeIcon : AppIcons.eyeOff,
                tooltip: isVisible ? S.visualEditorHide : S.visualEditorShow,
                color: isVisible ? muted : accent,
                onTap: onToggleVisibility,
              ),
              if (onDuplicate != null)
                _ActionButton(
                  icon: AppIcons.copy01,
                  tooltip: S.visualEditorDuplicate,
                  color: muted,
                  onTap: onDuplicate!,
                ),
              if (onDelete != null)
                _ActionButton(
                  icon: AppIcons.delete01,
                  tooltip: S.visualEditorDelete,
                  color: AppColor.errorColor,
                  onTap: onDelete!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'header' => AppIcons.home01,
      'bannerCarousel' || 'promoBanner' => AppIcons.promotion,
      'categoryList' => AppIcons.folder01,
      'productStrip' || 'productGrid' => AppIcons.shoppingBag01,
      'bundleList' => AppIcons.cube,
      'searchBar' => AppIcons.search01,
      'text' => Icons.text_fields,
      'heading' => Icons.title,
      'button' => Icons.smart_button,
      'image' => AppIcons.image01,
      'divider' => Icons.horizontal_rule,
      'spacer' => Icons.space_bar,
      'column' => Icons.view_column,
      _ => AppIcons.layers01,
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final heading = dark ? AppColor.darkText : AppColor.adminHeading;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppDimensions.iconSizeSm, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: AppFontSizes.size12,
              fontWeight: AppFontWeights.semiBold,
              color: heading,
            ),
          ),
        ],
      ),
    );
  }
}
