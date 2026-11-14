import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';

/// لوحة مكتبة المكوّنات — تعرض المكوّنات المتاحة للصفحة المحددة
/// مجمّعةً بحسب الفئة.
class ComponentLibraryPanel extends StatefulWidget {
  const ComponentLibraryPanel({
    super.key,
    required this.pageId,
    required this.availableComponents,
    required this.onAddComponent,
  });

  final String pageId;
  final List<ComponentRegistryEntry> availableComponents;
  final void Function({
    required String pageId,
    required String componentType,
    String? parentId,
    int? index,
  }) onAddComponent;

  @override
  State<ComponentLibraryPanel> createState() => _ComponentLibraryPanelState();
}

class _ComponentLibraryPanelState extends State<ComponentLibraryPanel> {
  String _filter = '';

  List<ComponentRegistryEntry> get _filtered {
    if (_filter.isEmpty) return widget.availableComponents;
    final lower = _filter.toLowerCase();
    return widget.availableComponents
        .where(
          (e) =>
              e.displayName.toLowerCase().contains(lower) ||
              e.description.toLowerCase().contains(lower) ||
              e.category.toLowerCase().contains(lower),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries = _filtered;
    final categories = <String>{};
    for (final e in entries) {
      categories.add(e.category);
    }

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
            icon: Icons.widgets_outlined,
            title: S.visualEditorLibrary,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _SearchField(
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? AdminEmptyState(
                    icon: Icons.widgets_outlined,
                    message: S.visualEditorNoComponentsFound,
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    children: [
                      for (final category in categories)
                        _CategorySection(
                          category: _categoryLabel(category),
                          entries: entries
                              .where((e) => e.category == category)
                              .toList(),
                          onAdd: (componentType) {
                            widget.onAddComponent(
                              pageId: widget.pageId,
                              componentType: componentType,
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) => switch (category) {
        'layout' => S.visualEditorCategoryLayout,
        'content' => S.visualEditorCategoryContent,
        'restaurant' => S.visualEditorCategoryRestaurant,
        'navigation' => S.visualEditorCategoryNavigation,
        _ => category,
      };
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.entries,
    required this.onAdd,
  });

  final String category;
  final List<ComponentRegistryEntry> entries;
  final void Function(String componentType) onAdd;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            category,
            style: TextStyle(
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.semiBold,
              color: muted,
              letterSpacing: AppLetterSpacings.space0_8,
            ),
          ),
        ),
        for (final entry in entries)
          _ComponentTile(entry: entry, onAdd: () => onAdd(entry.componentType)),
      ],
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.entry, required this.onAdd});

  final ComponentRegistryEntry entry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final bodyColor = dark ? AppColor.darkText : AppColor.adminBody;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null, // الضغط يفتح توضيحًا لاحقًا
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.px32,
                height: AppSizes.px32,
                decoration: BoxDecoration(
                  color: dark
                      ? AppColor.darkSurfaceContainer
                      : AppColor.adminAccentSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconForCategory(entry.category),
                  size: AppDimensions.iconSizeSm,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: TextStyle(
                        fontSize: AppFontSizes.size12,
                        fontWeight: AppFontWeights.medium,
                        color: bodyColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      entry.description,
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
              Tooltip(
                message: S.visualEditorAddComponent,
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      AppIcons.add01,
                      size: AppDimensions.iconSizeSm,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) => switch (category) {
        'layout' => Icons.view_column,
        'content' => Icons.text_fields,
        'restaurant' => AppIcons.coffee01,
        'navigation' => AppIcons.home01,
        _ => AppIcons.layers01,
      };
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      onChanged: onChanged,
      style: TextStyle(
        fontSize: AppFontSizes.size12,
        color: dark ? AppColor.darkText : AppColor.adminBody,
      ),
      decoration: InputDecoration(
        hintText: S.visualEditorSearchComponents,
        hintStyle: TextStyle(
          fontSize: AppFontSizes.size12,
          color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
        ),
        prefixIcon: Icon(
          AppIcons.search01,
          size: AppDimensions.iconSizeSm,
          color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: dark ? AppColor.secondaryColor : AppColor.adminAccent,
          ),
        ),
        filled: true,
        fillColor: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
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
