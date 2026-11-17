import 'package:flutter/material.dart';

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

/// لوحة مفتش الخصائص اليمينية الاحترافية (Right Properties Inspector).
///
/// تعرض خصائص وتصميم وبيانات المكون المحدد في 3 تبويبات واضحة:
/// 1. Properties: الخصائص العامة والنصوص ثنائية اللغة.
/// 2. Design: التخطيط، المسافات، المظهر، الخطوط، والصور.
/// 3. Data & Actions: ربط المنتجات، الفئات، والإجراءات.
class VisualEditorRightInspector extends StatefulWidget {
  const VisualEditorRightInspector({
    super.key,
    required this.selectedComponent,
    required this.onPropertyChanged,
    required this.onResetProperty,
    required this.imagePermissions,
    this.onClose,
  });

  final EditableComponent? selectedComponent;
  final void Function({
    required String componentId,
    required String propertyKey,
    required dynamic value,
  }) onPropertyChanged;
  final void Function({
    required String componentId,
    required String propertyKey,
  }) onResetProperty;
  final Set<String> imagePermissions;
  final VoidCallback? onClose;

  @override
  State<VisualEditorRightInspector> createState() =>
      _VisualEditorRightInspectorState();
}

class _VisualEditorRightInspectorState
    extends State<VisualEditorRightInspector>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = VisualEditorTokens.surface(context);
    final borderColor = VisualEditorTokens.border(context);

    return Container(
      width: VisualEditorTokens.inspectorWidth,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: BorderDirectional(
          start: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: widget.selectedComponent == null
          ? _buildEmptyState(context, dark)
          : _buildInspectorBody(context, widget.selectedComponent!, dark),
    );
  }

  // --- الحالة الفارغة عند عدم تحديد أي عنصر ---
  Widget _buildEmptyState(BuildContext context, bool dark) {
    final textMuted = VisualEditorTokens.textMuted(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: dark
                  ? VisualEditorTokens.darkSurfaceSecondary
                  : VisualEditorTokens.surfaceSoftCreamSecondary,
              shape: BoxShape.circle,
              border: Border.all(
                color: VisualEditorTokens.border(context),
                width: 1.0,
              ),
            ),
            child: Icon(
              Icons.touch_app_outlined,
              size: 26,
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
              color: textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: dark
                  ? VisualEditorTokens.darkSurfaceSecondary
                  : VisualEditorTokens.primaryOliveGreenLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: VisualEditorTokens.primaryOliveGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'انقر على أي عنصر في شاشة المعاينة أو من لوحة الطبقات لتعديل خصائصه.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: VisualEditorTokens.primaryOliveGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- جسم المفتش عند تحديد عنصر ---
  Widget _buildInspectorBody(
    BuildContext context,
    EditableComponent component,
    bool dark,
  ) {
    final entry = ComponentRegistry.get(component.componentType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة العنصر المحدد
        _buildHeader(context, component, entry, dark),

        // تبويبات المفتش (Properties / Design / Data)
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: VisualEditorTokens.border(context),
                width: 1.0,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: VisualEditorTokens.primaryOliveGreen,
            unselectedLabelColor: VisualEditorTokens.textMuted(context),
            indicatorColor: VisualEditorTokens.primaryOliveGreen,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: AppFontWeights.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: AppFontWeights.medium,
            ),
            tabs: const [
              Tab(text: 'الخصائص'),
              Tab(text: 'التصميم'),
              Tab(text: 'البيانات والأكشن'),
            ],
          ),
        ),

        // محتوى التبويبات
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Properties
              _buildPropertiesTab(context, component),
              // 2. Design
              _buildDesignTab(context, component),
              // 3. Data & Actions
              _buildDataTab(context, component),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    EditableComponent component,
    ComponentRegistryEntry? entry,
    bool dark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: dark
            ? VisualEditorTokens.darkSurfaceSecondary
            : VisualEditorTokens.surfaceSoftCreamSecondary,
        border: Border(
          bottom: BorderSide(
            color: VisualEditorTokens.border(context),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: VisualEditorTokens.primaryOliveGreenLight,
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            ),
            child: const Icon(
              AppIcons.tune,
              size: 16,
              color: VisualEditorTokens.primaryOliveGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry?.displayName ?? component.componentType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.bold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
                Text(
                  'ID: ${component.componentId}',
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
          if (widget.onClose != null)
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'إغلاق',
            ),
        ],
      ),
    );
  }

  // --- تبويب الخصائص ---
  Widget _buildPropertiesTab(BuildContext context, EditableComponent component) {
    return PropertiesInspectorPanel(
      component: component,
      onPropertyChanged: widget.onPropertyChanged,
      onResetProperty: widget.onResetProperty,
      onBrowseImages: () => showVisualEditorImageAssetPicker(
        context: context,
        repository: VisualEditorImageAssetRepository(),
        permissions: widget.imagePermissions,
      ),
    );
  }

  // --- تبويب التصميم (Layout / Spacing / Appearance / Media) ---
  Widget _buildDesignTab(BuildContext context, EditableComponent component) {
    // يستعرض نفس الخصائص المصممة من PropertiesInspectorPanel بتمرير مباشر
    return PropertiesInspectorPanel(
      component: component,
      onPropertyChanged: widget.onPropertyChanged,
      onResetProperty: widget.onResetProperty,
      onBrowseImages: () => showVisualEditorImageAssetPicker(
        context: context,
        repository: VisualEditorImageAssetRepository(),
        permissions: widget.imagePermissions,
      ),
    );
  }

  // --- تبويب البيانات والإجراءات ---
  Widget _buildDataTab(BuildContext context, EditableComponent component) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ListView(
        children: [
          _buildInfoCard(
            title: 'ربط البيانات التلقائي',
            description:
                'هذا المكون مربوط بنظام بيانات القائمة الحية لمتجر القهوة، ويتلقى المنتجات والفئات من قاعدة البيانات تلقائياً.',
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoCard(
            title: 'إجراءات التفاعل (Actions)',
            description:
                'النقر على بطاقات المكون في تطبيق العميل يوجه تلقائياً لصفحة تفاصيل المنتج أو إضافة السلة حسب إعدادات القالب.',
            icon: Icons.touch_app_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: dark
            ? VisualEditorTokens.darkSurfaceSecondary
            : VisualEditorTokens.surfaceSoftCreamSecondary,
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
        border: Border.all(color: VisualEditorTokens.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: VisualEditorTokens.primaryOliveGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFontWeights.bold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: VisualEditorTokens.textMuted(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
