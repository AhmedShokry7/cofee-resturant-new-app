import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/templates_dialog.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/theme_studio_dialog.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_image_asset_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// تبويبات الشريط الجانبي الأيسر بأسلوب FlutterFlow
enum FlutterFlowLeftTab {
  layers,
  pages,
  components,
  theme,
  assets,
  templates,
}

/// الشريط الجانبي الأيسر المتكامل بنمط FlutterFlow:
/// يجمع بين شريط التنقل الرأسي (Icon Rail) ومساحة العمل المتغيرة
/// التي تعرض إما شجرة الطبقات، أو مستكشف كل صفحات التطبيق، أو مكتبة المكونات.
class FlutterFlowLeftSidebar extends StatefulWidget {
  const FlutterFlowLeftSidebar({
    super.key,
    required this.state,
    required this.cubit,
    required this.pageId,
    required this.onPageSelected,
    required this.onAddComponent,
    this.splashGroup,
    this.onSplashGroup,
    this.imagePermissions = const <String>{},
    this.canPublish = true,
    this.onShowProperties,
    this.initialTab = FlutterFlowLeftTab.layers,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;
  final String pageId;
  final ValueChanged<String> onPageSelected;
  final ValueChanged<String> onAddComponent;
  final String? splashGroup;
  final void Function(String id, String group)? onSplashGroup;
  final Set<String> imagePermissions;
  final bool canPublish;
  final VoidCallback? onShowProperties;
  final FlutterFlowLeftTab initialTab;

  @override
  State<FlutterFlowLeftSidebar> createState() => _FlutterFlowLeftSidebarState();
}

class _FlutterFlowLeftSidebarState extends State<FlutterFlowLeftSidebar> {
  late FlutterFlowLeftTab _activeTab;
  String _pageSearchQuery = '';
  String _componentSearchQuery = '';
  String _componentCategory = 'all';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPanel),
        border: Border.all(color: VisualEditorTokens.border(context)),
        boxShadow: VisualEditorTokens.panelShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPanel),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. شريط الأيقونات الرأسي المصغر (FlutterFlow Navigation Rail)
            _buildNavigationRail(context),

            // فاصل خفيف
            Container(
              width: 1,
              color: VisualEditorTokens.border(context),
            ),

            // 2. مساحة محتوى الأداة النشطة (Layers / Pages / Components)
            Expanded(
              child: _buildActiveWorkspace(context),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. شريط الأيقونات الرأسي (FlutterFlow Rail) ---
  Widget _buildNavigationRail(BuildContext context) {
    return Container(
      width: 58,
      color: VisualEditorTokens.railBg(context),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _railButton(
            tab: FlutterFlowLeftTab.layers,
            icon: Icons.layers_rounded,
            tooltip: S.visualEditorLayers,
            label: 'الطبقات',
          ),
          _railButton(
            tab: FlutterFlowLeftTab.pages,
            icon: Icons.grid_view_rounded,
            tooltip: 'صفحات التطبيق',
            label: 'الصفحات',
          ),
          _railButton(
            tab: FlutterFlowLeftTab.components,
            icon: Icons.widgets_rounded,
            tooltip: 'إضافة مكونات',
            label: 'المكونات',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          _railActionButton(
            icon: Icons.palette_outlined,
            tooltip: 'الهوية البصرية',
            label: 'الهوية',
            onTap: () => showVisualEditorThemeStudio(context, widget.cubit),
          ),
          _railActionButton(
            icon: Icons.photo_library_outlined,
            tooltip: 'مكتبة الصور',
            label: 'الوسائط',
            onTap: () => showVisualEditorImageAssetPicker(
              context: context,
              repository: VisualEditorImageAssetRepository(),
              permissions: widget.imagePermissions,
            ),
          ),
          _railActionButton(
            icon: Icons.dashboard_customize_outlined,
            tooltip: 'القوالب الجاهزة',
            label: 'القوالب',
            onTap: () => showVisualEditorTemplates(context, widget.cubit),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Tooltip(
              message: 'استوديو FlutterFlow للقهوة',
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: VisualEditorTokens.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railButton({
    required FlutterFlowLeftTab tab,
    required IconData icon,
    required String tooltip,
    required String label,
  }) {
    final isSelected = _activeTab == tab;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: InkWell(
          onTap: () => setState(() => _activeTab = tab),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? VisualEditorTokens.primaryOliveGreen
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: VisualEditorTokens.primaryOliveGreen.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected
                        ? AppFontWeights.bold
                        : AppFontWeights.medium,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _railActionButton({
    required IconData icon,
    required String tooltip,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: AppFontWeights.medium,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. محتوى مساحة العمل النشطة ---
  Widget _buildActiveWorkspace(BuildContext context) {
    switch (_activeTab) {
      case FlutterFlowLeftTab.layers:
        return ComponentTreePanel(
          key: ValueKey('layers-${widget.pageId}'),
          pageId: widget.pageId,
          components: widget.state.getComponentsForPage(widget.pageId),
          selectedComponentId: widget.state.selectedComponentId,
          splashGroup: widget.splashGroup,
          isEmbedded: true,
          onSplashGroup: (id, group) {
            widget.cubit.selectComponent(id);
            widget.onSplashGroup?.call(id, group);
            widget.onShowProperties?.call();
          },
          onSelect: (id) {
            widget.cubit.selectComponent(id);
            widget.onShowProperties?.call();
          },
          onReorder: widget.cubit.reorderComponent,
          onDelete: widget.cubit.deleteComponent,
          onDuplicate: widget.cubit.duplicateComponent,
          onToggleVisibility: (componentId) {
            final component = widget.state.findComponent(componentId);
            if (component?.componentType == 'splashSettings') {
              final imageVisible =
                  component!.properties['imageVisible'] as bool? ?? true;
              widget.cubit.updateProperty(
                componentId: componentId,
                propertyKey: 'imageVisible',
                value: !imageVisible,
              );
            } else {
              widget.cubit.toggleComponentVisibility(componentId);
            }
          },
          onAddComponent: widget.onAddComponent,
        );

      case FlutterFlowLeftTab.pages:
        return _buildPagesExplorer(context);

      case FlutterFlowLeftTab.components:
        return _buildComponentsPalette(context);

      default:
        return const SizedBox.shrink();
    }
  }

  // --- مستكشف كل صفحات التطبيق (FlutterFlow Pages Explorer) ---
  Widget _buildPagesExplorer(BuildContext context) {
    final query = _pageSearchQuery.trim().toLowerCase();
    final allPages = EditorPages.pages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة اللوحة
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: VisualEditorTokens.surfaceSecondary(context),
            border: Border(
              bottom: BorderSide(color: VisualEditorTokens.border(context)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: VisualEditorTokens.primaryOliveGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  size: 16,
                  color: VisualEditorTokens.primaryOliveGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صفحات التطبيق (${allPages.length})',
                      style: TextStyle(
                        fontSize: AppFontSizes.size12_5,
                        fontWeight: AppFontWeights.bold,
                        color: VisualEditorTokens.text(context),
                      ),
                    ),
                    Text(
                      'تعديل موحد لكل الشاشات',
                      style: TextStyle(
                        fontSize: AppFontSizes.size9_5,
                        color: VisualEditorTokens.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // حقل البحث السريع في الصفحات
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            onChanged: (v) => setState(() => _pageSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'ابحث في صفحات التطبيق…',
              hintStyle: TextStyle(
                fontSize: 11.5,
                color: VisualEditorTokens.textMuted(context),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 16,
                color: VisualEditorTokens.textMuted(context),
              ),
              isDense: true,
              filled: true,
              fillColor: VisualEditorTokens.surfaceSecondary(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                borderSide: BorderSide(
                  color: VisualEditorTokens.border(context),
                  width: 0.8,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                borderSide: BorderSide(
                  color: VisualEditorTokens.border(context),
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                borderSide: const BorderSide(
                  color: VisualEditorTokens.primaryOliveGreen,
                  width: 1.2,
                ),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),

        // قائمة الصفحات المصنفة
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            children: [
              for (final (catTitle, catIcon, pageIds) in editorPageCategories) ...[
                () {
                  final filtered = pageIds
                      .map(EditorPages.findById)
                      .whereType<EditorPage>()
                      .where((p) =>
                          query.isEmpty ||
                          p.label.toLowerCase().contains(query) ||
                          p.pageId.toLowerCase().contains(query) ||
                          p.routeName.toLowerCase().contains(query))
                      .toList();

                  if (filtered.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 6),
                        child: Row(
                          children: [
                            Icon(
                              catIcon,
                              size: 14,
                              color: VisualEditorTokens.primaryOliveGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              catTitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: AppFontWeights.bold,
                                color: VisualEditorTokens.text(context),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: VisualEditorTokens.surfaceSecondary(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: VisualEditorTokens.border(context),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${filtered.length}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: AppFontWeights.medium,
                                  color: VisualEditorTokens.textMuted(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final page in filtered)
                        _buildPageTile(context, page),
                    ],
                  );
                }(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageTile(BuildContext context, EditorPage page) {
    final isSelected = widget.pageId == page.pageId;
    final pageComponents = widget.state.getComponentsForPage(page.pageId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? VisualEditorTokens.accentSurface(context)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
        child: InkWell(
          onTap: () {
            widget.onPageSelected(page.pageId);
            // العودة لتبويب الطبقات تلقائيًا لرؤية مكونات الصفحة
            setState(() => _activeTab = FlutterFlowLeftTab.layers);
          },
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              border: isSelected
                  ? Border.all(color: VisualEditorTokens.accentBorder(context))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.phone_android_rounded : Icons.smartphone_outlined,
                  size: 16,
                  color: isSelected
                      ? VisualEditorTokens.primaryOliveGreen
                      : VisualEditorTokens.textMuted(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? AppFontWeights.bold
                              : AppFontWeights.medium,
                          color: isSelected
                              ? VisualEditorTokens.primaryOliveGreen
                              : VisualEditorTokens.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            page.routeName,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: VisualEditorTokens.textMuted(context),
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${pageComponents.length} عنصر',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: VisualEditorTokens.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: VisualEditorTokens.primaryOliveGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'نشطة',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- مكتبة عناصر الواجهة (FlutterFlow Component Palette) ---
  Widget _buildComponentsPalette(BuildContext context) {
    final query = _componentSearchQuery.trim().toLowerCase();
    final allowedTypes = ComponentRegistry.getForPage(widget.pageId)
        .map((e) => e.componentType)
        .toSet();
    final allEntries = ComponentRegistry.all;

    final filtered = allEntries.where((entry) {
      if (query.isNotEmpty) {
        final match = entry.displayName.toLowerCase().contains(query) ||
            entry.componentType.toLowerCase().contains(query) ||
            entry.description.toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_componentCategory != 'all' && entry.category != _componentCategory) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة اللوحة
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: VisualEditorTokens.surfaceSecondary(context),
            border: Border(
              bottom: BorderSide(color: VisualEditorTokens.border(context)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: VisualEditorTokens.primaryOliveGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  size: 16,
                  color: VisualEditorTokens.primaryOliveGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مكتبة عناصر الواجهة',
                      style: TextStyle(
                        fontSize: AppFontSizes.size12_5,
                        fontWeight: AppFontWeights.bold,
                        color: VisualEditorTokens.text(context),
                      ),
                    ),
                    Text(
                      'أضف عناصر مباشرة إلى صفحة: ${EditorPages.findById(widget.pageId)?.label ?? widget.pageId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.size9_5,
                        color: VisualEditorTokens.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // شريط البحث وتصفية الفئات
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _componentSearchQuery = v),
                decoration: InputDecoration(
                  hintText: 'ابحث في عناصر الواجهة…',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: VisualEditorTokens.surfaceSecondary(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                    borderSide: BorderSide(
                      color: VisualEditorTokens.border(context),
                      width: 0.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                    borderSide: BorderSide(
                      color: VisualEditorTokens.border(context),
                      width: 0.8,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'الكل'),
                    const SizedBox(width: 5),
                    _filterChip('layout', 'التخطيط'),
                    const SizedBox(width: 5),
                    _filterChip('content', 'المحتوى'),
                    const SizedBox(width: 5),
                    _filterChip('restaurant', 'المتجر'),
                    const SizedBox(width: 5),
                    _filterChip('navigation', 'التنقل'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // شبكة / قائمة المكونات
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا توجد عناصر مطابقة',
                      style: TextStyle(
                        fontSize: 12,
                        color: VisualEditorTokens.textMuted(context),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isAllowed = allowedTypes.isEmpty ||
                        allowedTypes.contains(entry.componentType);

                    return _buildComponentCard(context, entry, isAllowed);
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String category, String label) {
    final isSelected = _componentCategory == category;
    return InkWell(
      onTap: () => setState(() => _componentCategory = category),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? VisualEditorTokens.primaryOliveGreen
              : VisualEditorTokens.surfaceSecondary(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? VisualEditorTokens.primaryOliveGreen
                : VisualEditorTokens.border(context),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? AppFontWeights.bold : AppFontWeights.regular,
            color: isSelected ? Colors.white : VisualEditorTokens.text(context),
          ),
        ),
      ),
    );
  }

  Widget _buildComponentCard(
    BuildContext context,
    ComponentRegistryEntry entry,
    bool isAllowed,
  ) {
    final icon = _iconForType(entry.componentType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VisualEditorTokens.surfaceSecondary(context),
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
          border: Border.all(
            color: VisualEditorTokens.border(context),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: VisualEditorTokens.primaryOliveGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: VisualEditorTokens.primaryOliveGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFontWeights.bold,
                      color: VisualEditorTokens.text(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: VisualEditorTokens.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: isAllowed
                  ? () {
                      widget.onAddComponent(entry.componentType);
                      // تحويل التبويب للطبقات لمشاهدة العنصر الجديد
                      setState(() => _activeTab = FlutterFlowLeftTab.layers);
                      widget.onShowProperties?.call();
                    }
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(0, 30),
                visualDensity: VisualDensity.compact,
                backgroundColor: isAllowed
                    ? VisualEditorTokens.primaryOliveGreen.withValues(alpha: 0.15)
                    : Colors.transparent,
                foregroundColor: VisualEditorTokens.primaryOliveGreen,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14),
                  SizedBox(width: 2),
                  Text(
                    'إضافة',
                    style: TextStyle(fontSize: 10.5, fontWeight: AppFontWeights.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
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
    _ => Icons.widgets_outlined,
  };
}
