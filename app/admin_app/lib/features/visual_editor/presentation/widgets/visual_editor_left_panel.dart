import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_library_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/templates_dialog.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/theme_studio_dialog.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_image_asset_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// الأداة المحددة في الشريط الرأسي الأيسر.
enum VisualEditorLeftTool {
  pages,
  layers,
  components,
  assets,
  templates,
  branding,
}

/// اللوحة الجانبية اليسارية المتكاملة (Professional Left Workspace Panel).
///
/// تتكون من:
/// 1. شريط أدوات رأسي (Vertical Navigation Rail / Activity Bar)
/// 2. لوحة عمل تفاعلية بجوارها تتغير محتوياتها حسب الأداة المختارة.
class VisualEditorLeftPanel extends StatefulWidget {
  const VisualEditorLeftPanel({
    super.key,
    required this.state,
    required this.cubit,
    required this.selectedPageId,
    required this.onPageSelected,
    this.initialTool = VisualEditorLeftTool.pages,
    this.isOpen = true,
    this.onToggleOpen,
    this.imagePermissions = const <String>{},
    this.canPublish = true,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;
  final String selectedPageId;
  final void Function(String) onPageSelected;
  final VisualEditorLeftTool initialTool;
  final bool isOpen;
  final VoidCallback? onToggleOpen;
  final Set<String> imagePermissions;
  final bool canPublish;

  @override
  State<VisualEditorLeftPanel> createState() => _VisualEditorLeftPanelState();
}

class _VisualEditorLeftPanelState extends State<VisualEditorLeftPanel> {
  late VisualEditorLeftTool _activeTool;
  String _pageSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeTool = widget.initialTool;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = VisualEditorTokens.surface(context);
    final borderColor = VisualEditorTokens.border(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: BorderDirectional(
          end: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. الشريط الرأسي الضيق (Vertical Navigation Rail)
          _buildActivityBar(context, dark),

          // 2. لوحة العمل المجاورة إذا كانت مفتوحة
          if (widget.isOpen) ...[
            Container(
              width: 1,
              color: borderColor,
            ),
            SizedBox(
              width: VisualEditorTokens.sidePanelWidth,
              child: _buildActiveToolDrawer(context, dark),
            ),
          ],
        ],
      ),
    );
  }

  // --- الشريط الرأسي (Activity Bar) ---
  Widget _buildActivityBar(BuildContext context, bool dark) {
    final surfaceSecondary = VisualEditorTokens.surfaceSecondary(context);
    final textMuted = VisualEditorTokens.textMuted(context);

    return Container(
      width: VisualEditorTokens.navRailWidth,
      color: surfaceSecondary,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          _buildRailItem(
            tool: VisualEditorLeftTool.pages,
            icon: Icons.pages_outlined,
            activeIcon: Icons.pages_rounded,
            label: 'الصفحات',
            dark: dark,
          ),
          _buildRailItem(
            tool: VisualEditorLeftTool.layers,
            icon: Icons.layers_outlined,
            activeIcon: Icons.layers_rounded,
            label: 'الطبقات',
            dark: dark,
          ),
          _buildRailItem(
            tool: VisualEditorLeftTool.components,
            icon: Icons.widgets_outlined,
            activeIcon: Icons.widgets_rounded,
            label: 'المكونات',
            dark: dark,
          ),
          _buildRailItem(
            tool: VisualEditorLeftTool.assets,
            icon: Icons.photo_library_outlined,
            activeIcon: Icons.photo_library_rounded,
            label: 'الوسائط',
            dark: dark,
          ),
          _buildRailItem(
            tool: VisualEditorLeftTool.templates,
            icon: Icons.dashboard_customize_outlined,
            activeIcon: Icons.dashboard_customize_rounded,
            label: 'القوالب',
            dark: dark,
          ),
          _buildRailItem(
            tool: VisualEditorLeftTool.branding,
            icon: Icons.palette_outlined,
            activeIcon: Icons.palette_rounded,
            label: 'الهوية',
            dark: dark,
          ),
          const Spacer(),
          // زر طي/فتح اللوحة الجانبية
          if (widget.onToggleOpen != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: IconButton(
                onPressed: widget.onToggleOpen,
                icon: Icon(
                  widget.isOpen
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                  size: 20,
                  color: textMuted,
                ),
                tooltip: widget.isOpen ? 'طي اللوحة' : 'توسيع اللوحة',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRailItem({
    required VisualEditorLeftTool tool,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool dark,
  }) {
    final isSelected = widget.isOpen && _activeTool == tool;
    final primary = VisualEditorTokens.primaryOliveGreen;
    final textMuted = VisualEditorTokens.textMuted(context);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () {
          if (widget.isOpen && _activeTool == tool) {
            // الضغط على الأداة النشطة يطوي اللوحة
            widget.onToggleOpen?.call();
          } else {
            setState(() => _activeTool = tool);
            if (!widget.isOpen) {
              widget.onToggleOpen?.call();
            }
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: isSelected ? primary : Colors.transparent,
                width: 3.0,
              ),
            ),
            color: isSelected
                ? (dark ? VisualEditorTokens.darkSurface : Colors.white)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 21,
                color: isSelected ? primary : textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? AppFontWeights.bold : AppFontWeights.medium,
                  color: isSelected ? primary : textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- لوحة العمل التفاعلية المجاورة ---
  Widget _buildActiveToolDrawer(BuildContext context, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDrawerHeader(context, dark),
        Expanded(
          child: switch (_activeTool) {
            VisualEditorLeftTool.pages => _buildPagesDrawer(context, dark),
            VisualEditorLeftTool.layers => _buildLayersDrawer(context, dark),
            VisualEditorLeftTool.components => _buildComponentsDrawer(context, dark),
            VisualEditorLeftTool.assets => _buildAssetsDrawer(context, dark),
            VisualEditorLeftTool.templates => _buildTemplatesDrawer(context, dark),
            VisualEditorLeftTool.branding => _buildBrandingDrawer(context, dark),
          },
        ),
      ],
    );
  }

  Widget _buildDrawerHeader(BuildContext context, bool dark) {
    final title = switch (_activeTool) {
      VisualEditorLeftTool.pages => 'صفحات تطبيق العميل',
      VisualEditorLeftTool.layers => S.visualEditorLayers,
      VisualEditorLeftTool.components => S.visualEditorLibrary,
      VisualEditorLeftTool.assets => 'مدير الوسائط والأصول',
      VisualEditorLeftTool.templates => S.visualEditorTemplates,
      VisualEditorLeftTool.branding => 'إعدادات الهوية والتصميم',
    };

    final subtitle = switch (_activeTool) {
      VisualEditorLeftTool.pages => 'اختر الصفحة المراد تحريرها ومعاينتها',
      VisualEditorLeftTool.layers => 'شجرة العناصر الحقيقية للصفحة الحالية',
      VisualEditorLeftTool.components => 'اسحب وأضف المكونات للتصميم',
      VisualEditorLeftTool.assets => 'إدارة الصور والملفات المرفوعة',
      VisualEditorLeftTool.templates => 'تطبيق القوالب الجاهزة أو الحفظ',
      VisualEditorLeftTool.branding => 'تخصيص الألوان والخطوط والأبعاد',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm + 4, AppSpacing.sm, AppSpacing.sm + 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: VisualEditorTokens.border(context),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.bold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onToggleOpen,
            icon: const Icon(Icons.close_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'إغلاق اللوحة',
          ),
        ],
      ),
    );
  }

  // --- A. Pages Drawer ---
  Widget _buildPagesDrawer(BuildContext context, bool dark) {
    final query = _pageSearchQuery.trim().toLowerCase();
    final allPages = PreviewPages.all;
    final filteredPages = query.isEmpty
        ? allPages
        : allPages.where((p) => p.label.toLowerCase().contains(query) || p.pageId.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            onChanged: (v) => setState(() => _pageSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'ابحث عن صفحة…',
              hintStyle: TextStyle(fontSize: 11.5, color: VisualEditorTokens.textMuted(context)),
              prefixIcon: const Icon(Icons.search_rounded, size: 16),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                borderSide: BorderSide(color: VisualEditorTokens.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                borderSide: BorderSide(color: VisualEditorTokens.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                borderSide: const BorderSide(color: VisualEditorTokens.primaryOliveGreen),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),

        // قائمة الصفحات الرائعة مع الحفاظ على ChoiceChip لمرور الاختبارات الحالية
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            itemCount: filteredPages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final page = filteredPages[index];
              final isSelected = widget.selectedPageId == page.pageId;

              return ChoiceChip(
                key: ValueKey('page_chip_${page.pageId}'),
                label: SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Icon(
                        page.isEditable ? Icons.web_rounded : Icons.lock_outline_rounded,
                        size: 14,
                        color: isSelected
                            ? (dark ? Colors.white : VisualEditorTokens.primaryOliveGreen)
                            : VisualEditorTokens.textMuted(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          page.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? AppFontWeights.bold : AppFontWeights.regular,
                            color: isSelected
                                ? (dark ? Colors.white : VisualEditorTokens.primaryOliveGreen)
                                : VisualEditorTokens.text(context),
                          ),
                        ),
                      ),
                      if (!page.isEditable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: VisualEditorTokens.secondaryCoffeeBrown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'للمعاينة',
                            style: TextStyle(
                              fontSize: 9,
                              color: VisualEditorTokens.secondaryCoffeeBrown,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  widget.onPageSelected(page.pageId);
                  widget.cubit.loadPage(page.pageId);
                },
                selectedColor: dark
                    ? VisualEditorTokens.primaryOliveGreen.withOpacity(0.3)
                    : VisualEditorTokens.primaryOliveGreenLight,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                  side: BorderSide(
                    color: isSelected
                        ? VisualEditorTokens.primaryOliveGreen
                        : VisualEditorTokens.border(context),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
    );
  }

  // --- B. Layers Drawer ---
  Widget _buildLayersDrawer(BuildContext context, bool dark) {
    return ComponentTreePanel(
      pageId: widget.selectedPageId,
      components: widget.state.getComponentsForPage(widget.selectedPageId),
      selectedComponentId: widget.state.selectedComponentId,
      onSelect: widget.cubit.selectComponent,
      onReorder: widget.cubit.reorderComponent,
      onDelete: widget.cubit.deleteComponent,
      onDuplicate: widget.cubit.duplicateComponent,
      onToggleVisibility: widget.cubit.toggleComponentVisibility,
      onAddComponent: (type) => widget.cubit.addComponent(
        pageId: widget.selectedPageId,
        componentType: type,
      ),
    );
  }

  // --- C. Components Drawer ---
  Widget _buildComponentsDrawer(BuildContext context, bool dark) {
    return ComponentLibraryPanel(
      pageId: widget.selectedPageId,
      availableComponents: ComponentRegistry.getForPage(widget.selectedPageId),
      onAddComponent: widget.cubit.addComponent,
    );
  }

  // --- D. Assets Drawer ---
  Widget _buildAssetsDrawer(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: dark ? VisualEditorTokens.darkSurfaceSecondary : VisualEditorTokens.surfaceSoftCreamSecondary,
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
              border: Border.all(color: VisualEditorTokens.border(context)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 36,
                  color: VisualEditorTokens.primaryOliveGreen,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'مستودع صور التطبيق',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.bold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تصفح، ارفع، واستبدل صور البانرات والقوائم والشعارات بسهولة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => showVisualEditorImageAssetPicker(
                    context: context,
                    repository: VisualEditorImageAssetRepository(),
                    permissions: widget.imagePermissions,
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                  label: const Text('فتح مكتبة الصور'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VisualEditorTokens.primaryOliveGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'نصائح الاستخدام',
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFontWeights.semiBold,
              color: VisualEditorTokens.text(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildTipRow('يتم تخزين الصور سحابياً عبر Supabase Storage بأمان.'),
          _buildTipRow('تجنب رفع صور بدقة مفرطة لتسريع تحميل التطبيق للعملاء.'),
          _buildTipRow('يمكنك قص وتعديل الصور قبل إدراجها في أي مكون.'),
        ],
      ),
    );
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: VisualEditorTokens.primaryOliveGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(fontSize: 11, color: VisualEditorTokens.textMuted(context)),
            ),
          ),
        ],
      ),
    );
  }

  // --- E. Templates Drawer ---
  Widget _buildTemplatesDrawer(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'قوالب التصميم الجاهزة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.bold,
              color: VisualEditorTokens.text(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'اختر قالباً متكاملاً ومدروساً للمقهى لتطبيقه بنقرة واحدة على المسودة الحالية.',
            style: TextStyle(fontSize: 11, color: VisualEditorTokens.textMuted(context)),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => showVisualEditorTemplates(context, widget.cubit),
            icon: const Icon(Icons.dashboard_customize_rounded, size: 16),
            label: const Text('استعراض وتطبيق القوالب'),
            style: FilledButton.styleFrom(
              backgroundColor: VisualEditorTokens.secondaryCoffeeBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- F. Branding / Settings Drawer ---
  Widget _buildBrandingDrawer(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'استوديو سمة وهوية المقهى',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.bold,
              color: VisualEditorTokens.text(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'تخصيص الألوان الأساسية، الثانوية، خلفيات الشاشات، واستدارة الحواف لتطبيق العميل.',
            style: TextStyle(fontSize: 11, color: VisualEditorTokens.textMuted(context)),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => showVisualEditorThemeStudio(context, widget.cubit),
            icon: const Icon(Icons.palette_rounded, size: 16),
            label: const Text('فتح استوديو الهوية البصرية'),
            style: FilledButton.styleFrom(
              backgroundColor: VisualEditorTokens.primaryOliveGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
