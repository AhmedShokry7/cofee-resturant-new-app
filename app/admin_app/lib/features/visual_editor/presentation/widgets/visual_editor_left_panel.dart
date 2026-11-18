import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_image_asset_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// الأداة المحددة في الشريط الرأسي الأيسر الداكن.
enum VisualEditorLeftTool {
  pages,
  layers,
  components,
  assets,
  templates,
  settings,
}

class _FeaturePagesGroup {
  const _FeaturePagesGroup({
    required this.title,
    required this.icon,
    required this.pageIds,
  });

  final String title;
  final IconData icon;
  final List<String> pageIds;
}

const _featureGroups = [
  _FeaturePagesGroup(
    title: 'الرئيسية والتسوق',
    icon: Icons.storefront_outlined,
    pageIds: ['home', 'categories', 'search', 'cart', 'favourites', 'settings'],
  ),
  _FeaturePagesGroup(
    title: 'الدخول والترحيب',
    icon: Icons.login_outlined,
    pageIds: [
      'splash',
      'welcome',
      'onboarding',
      'auth',
      'sign_up',
      'forget_password',
      'reset_password',
      'phone_auth',
      'email_auth',
    ],
  ),
  _FeaturePagesGroup(
    title: 'الطلب والدفع',
    icon: Icons.payment_outlined,
    pageIds: [
      'checkout',
      'shipping_addresses',
      'add_address',
      'payment_method',
      'add_card',
      'payment_success',
      'e_receipt',
      'coupon',
    ],
  ),
  _FeaturePagesGroup(
    title: 'الحساب والولاء',
    icon: Icons.card_membership_outlined,
    pageIds: [
      'orders',
      'edit_profile',
      'saved_cards',
      'addresses',
      'address_form',
      'loyalty',
      'subscription_plans',
      'subscription_details',
      'cashier_subscription',
    ],
  ),
  _FeaturePagesGroup(
    title: 'الإعدادات والمساعدة',
    icon: Icons.settings_suggest_outlined,
    pageIds: [
      'notifications',
      'notification_settings',
      'help',
      'privacy',
      'assistant_memory',
    ],
  ),
];

/// اللوحة الجانبية اليسارية المتكاملة المطابقة تماماً للصورة المرجعية:
/// 1. شريط رأسي داكن أخضر زيتوني على أقصى الحافة بالأدوات الست:
///    [الصفحات]، [الطبقات]، [المكونات]، [الصور]، [المكونات الجاهزة]، [الإعدادات].
/// 2. لوحة العمل المجاورة بعرض 280-300px وتحتوي على:
///    - قائمة الصفحات مع زر "+ إضافة صفحة" وحقل البحث.
///    - شجرة الطبقات القابلة للطي `شجرة الطبقات 🗂️`.
///    - مكتبة المكونات السريعة `مكتبة المكونات 🧩` مع التصنيفات وبطاقات الإضافة.
class VisualEditorLeftPanel extends StatefulWidget {
  const VisualEditorLeftPanel({
    super.key,
    required this.state,
    required this.cubit,
    required this.selectedPageId,
    required this.onPageSelected,
    this.onAddComponent,
    this.onDragStateChanged,
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
  final ValueChanged<String>? onAddComponent;
  final ValueChanged<bool>? onDragStateChanged;
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
  String _componentSearchQuery = '';
  int _selectedComponentCategory =
      0; // 0: الكل, 1: التخطيط, 2: النصوص, 3: الصور

  bool _isLayersExpanded = true;
  bool _isComponentsExpanded = true;

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
          // 1. الشريط الرأسي الداكن (Dark Olive Navigation Rail)
          _buildDarkNavigationRail(context, dark),

          // 2. لوحة العمل المجاورة
          Container(width: 1, color: borderColor),
          SizedBox(
            width: VisualEditorTokens.sidePanelWidth,
            child: _buildLeftWorkspaceContent(context, dark),
          ),
        ],
      ),
    );
  }

  // --- 1. الشريط الرأسي الداكن الأخضر الزيتوني ---
  Widget _buildDarkNavigationRail(BuildContext context, bool dark) {
    const railColor = Color(0xFF1E3527); // Dark olive green

    return Container(
      width: VisualEditorTokens.navRailWidth,
      color: railColor,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          _buildRailIconItem(
            tool: VisualEditorLeftTool.pages,
            icon: Icons.grid_view_rounded,
            label: 'الصفحات',
          ),
          _buildRailIconItem(
            tool: VisualEditorLeftTool.layers,
            icon: Icons.layers_outlined,
            label: 'الطبقات',
          ),
          _buildRailIconItem(
            tool: VisualEditorLeftTool.components,
            icon: Icons.widgets_outlined,
            label: 'المكونات',
          ),
          _buildRailIconItem(
            tool: VisualEditorLeftTool.assets,
            icon: Icons.photo_outlined,
            label: 'الصور',
          ),
          _buildRailIconItem(
            tool: VisualEditorLeftTool.templates,
            icon: Icons.view_quilt_outlined,
            label: 'المكونات الجاهزة',
          ),
          _buildRailIconItem(
            tool: VisualEditorLeftTool.settings,
            icon: Icons.settings_outlined,
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _buildRailIconItem({
    required VisualEditorLeftTool tool,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTool == tool;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () {
          setState(() => _activeTool = tool);
          if (tool == VisualEditorLeftTool.templates) {
            showVisualEditorTemplates(context, widget.cubit);
          } else if (tool == VisualEditorLeftTool.assets) {
            showVisualEditorImageAssetPicker(
              context: context,
              repository: VisualEditorImageAssetRepository(),
              permissions: widget.imagePermissions,
            );
          } else if (tool == VisualEditorLeftTool.settings) {
            showVisualEditorThemeStudio(context, widget.cubit);
          }
        },
        child: Container(
          width: 52,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E5A3D) : Colors.transparent,
            borderRadius: BorderRadius.circular(
              VisualEditorTokens.radiusSm + 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFFB5C4B9),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected
                      ? AppFontWeights.bold
                      : AppFontWeights.regular,
                  color: isSelected ? Colors.white : const Color(0xFFB5C4B9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. محتوى لوحة العمل المجاورة ---
  Widget _buildLeftWorkspaceContent(BuildContext context, bool dark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. ترويسة الصفحات مع زر "+ إضافة صفحة"
          _buildPagesHeader(context, dark),

          // B. حقل البحث عن صفحة
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _pageSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن صفحة…',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: VisualEditorTokens.textMuted(context),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 15),
                isDense: true,
                filled: true,
                fillColor: dark
                    ? VisualEditorTokens.darkSurfaceSecondary
                    : VisualEditorTokens.surfaceSoftCreamSecondary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusSm,
                  ),
                  borderSide: BorderSide(
                    color: VisualEditorTokens.border(context),
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusSm,
                  ),
                  borderSide: BorderSide(
                    color: VisualEditorTokens.border(context),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusSm,
                  ),
                  borderSide: const BorderSide(
                    color: VisualEditorTokens.primaryOliveGreen,
                    width: 1.2,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 11.5),
            ),
          ),

          // C. قائمة الصفحات مع جميع الـ 37 ChoiceChips المطلوبة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: _buildPagesListWithChips(context, dark),
          ),

          const SizedBox(height: AppSpacing.xs),
          Divider(color: VisualEditorTokens.border(context), height: 1),

          // D. أكورديون شجرة الطبقات 🗂️
          _buildLayersAccordion(context, dark),

          Divider(color: VisualEditorTokens.border(context), height: 1),

          // E. أكورديون مكتبة المكونات 🧩
          _buildComponentsAccordion(context, dark),
        ],
      ),
    );
  }

  // --- ترويسة قسم الصفحات مع زر "+ إضافة صفحة" ---
  Widget _buildPagesHeader(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        4,
      ),
      child: Row(
        children: [
          // العنوان "الصفحات" وتسمية "صفحات تطبيق العميل" للاختبارات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الصفحات',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.bold,
                    color: VisualEditorTokens.text(context),
                  ),
                ),
                Text(
                  'صفحات تطبيق العميل',
                  style: TextStyle(
                    fontSize: 9,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                ),
              ],
            ),
          ),

          // زر "+ إضافة صفحة"
          Material(
            color: VisualEditorTokens.primaryOliveGreen,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            child: InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('إضافة صفحة جديدة'),
                  content: const Text(
                    'إضافة صفحة مستقلة تحتاج أولًا إلى إنشاء الشاشة والمسار '
                    'في تطبيق العميل وإضافتهما إلى عقد التصميم. يمكنك حاليًا '
                    'تعديل الصفحات الموجودة في قائمة المحرر.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('حسنًا'),
                    ),
                  ],
                ),
              ),
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'إضافة صفحة',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFontWeights.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- قائمة الصفحات مع جميع الـ 37 ChoiceChip في صفوف تمرير أفقية ---
  Widget _buildPagesListWithChips(BuildContext context, bool dark) {
    final pageMap = {for (final p in PreviewPages.all) p.pageId: p};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in _featureGroups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                Icon(
                  group.icon,
                  size: 12,
                  color: VisualEditorTokens.textMuted(context),
                ),
                const SizedBox(width: 4),
                Text(
                  group.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: AppFontWeights.semiBold,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final id in group.pageIds)
                  if (pageMap[id] case final page?)
                    if (_pageSearchQuery.trim().isEmpty ||
                        page.label.toLowerCase().contains(
                          _pageSearchQuery.trim().toLowerCase(),
                        ) ||
                        page.pageId.toLowerCase().contains(
                          _pageSearchQuery.trim().toLowerCase(),
                        ))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: 4,
                          bottom: 2,
                        ),
                        child: ChoiceChip(
                          key: ValueKey('page_chip_${page.pageId}'),
                          label: Text(page.label),
                          selected: widget.selectedPageId == page.pageId,
                          onSelected: (_) {
                            widget.onPageSelected(page.pageId);
                            widget.cubit.loadPage(page.pageId);
                          },
                          avatar: widget.selectedPageId == page.pageId
                              ? const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: VisualEditorTokens.primaryOliveGreen,
                                )
                              : (page.isEditable
                                    ? null
                                    : const Icon(AppIcons.lock, size: 10)),
                          labelStyle: TextStyle(
                            fontSize: 10.5,
                            fontWeight: widget.selectedPageId == page.pageId
                                ? AppFontWeights.bold
                                : AppFontWeights.regular,
                            color: widget.selectedPageId == page.pageId
                                ? VisualEditorTokens.primaryOliveGreen
                                : VisualEditorTokens.text(context),
                          ),
                          selectedColor:
                              VisualEditorTokens.primaryOliveGreenLight,
                          backgroundColor: dark
                              ? VisualEditorTokens.darkSurfaceSecondary
                              : VisualEditorTokens.surfaceSoftCreamSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              VisualEditorTokens.radiusSm,
                            ),
                            side: BorderSide(
                              color: widget.selectedPageId == page.pageId
                                  ? VisualEditorTokens.primaryOliveGreen
                                  : VisualEditorTokens.border(context),
                              width: widget.selectedPageId == page.pageId
                                  ? 1.0
                                  : 0.6,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- D. أكورديون شجرة الطبقات 🗂️ ---
  Widget _buildLayersAccordion(BuildContext context, bool dark) {
    final components = widget.state.getComponentsForPage(widget.selectedPageId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة الأكورديون
        InkWell(
          onTap: () => setState(() => _isLayersExpanded = !_isLayersExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.layers_rounded,
                      size: 14,
                      color: VisualEditorTokens.primaryOliveGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'شجرة الطبقات 🗂️',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.bold,
                        color: VisualEditorTokens.text(context),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isLayersExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: VisualEditorTokens.textMuted(context),
                ),
              ],
            ),
          ),
        ),

        // قائمة الطبقات عند الفتح
        if (_isLayersExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              children: [
                if (components.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      'لا توجد عناصر مضافة بعد',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: VisualEditorTokens.textMuted(context),
                      ),
                    ),
                  )
                else
                  for (final comp in components)
                    _buildLayerItemRow(context, comp, dark),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLayerItemRow(
    BuildContext context,
    EditableComponent comp,
    bool dark,
  ) {
    final isSelected = widget.state.selectedComponentId == comp.componentId;
    final entry = ComponentRegistry.get(comp.componentType);
    final name = entry?.displayName ?? comp.componentType;
    final isVisible = comp.properties['visible'] as bool? ?? true;
    final isLocked = comp.classification == ComponentClassification.protected;

    return InkWell(
      onTap: () => widget.cubit.selectComponent(comp.componentId),
      borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? VisualEditorTokens.primaryOliveGreenLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
          border: isSelected
              ? Border.all(
                  color: VisualEditorTokens.primaryOliveGreen.withAlpha(100),
                  width: 0.8,
                )
              : null,
        ),
        child: Row(
          children: [
            // أيقونة السحب والمحاذاة ::
            Icon(
              Icons.drag_indicator_rounded,
              size: 13,
              color: VisualEditorTokens.textMuted(context),
            ),
            const SizedBox(width: 4),

            // اسم الطبقة
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected
                      ? AppFontWeights.bold
                      : AppFontWeights.regular,
                  color: isSelected
                      ? VisualEditorTokens.primaryOliveGreen
                      : VisualEditorTokens.text(context),
                ),
              ),
            ),

            // أيقونة القفل أو الرؤية
            if (isLocked)
              const Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: VisualEditorTokens.secondaryCoffeeBrown,
              )
            else
              IconButton(
                onPressed: () =>
                    widget.cubit.toggleComponentVisibility(comp.componentId),
                icon: Icon(
                  isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 13,
                  color: isVisible
                      ? VisualEditorTokens.textMuted(context)
                      : Colors.red,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_left_rounded,
              size: 14,
              color: VisualEditorTokens.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }

  // --- E. أكورديون مكتبة المكونات 🧩 ---
  Widget _buildComponentsAccordion(BuildContext context, bool dark) {
    const categories = ['الكل', 'التخطيط', 'النصوص', 'الصور'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة الأكورديون
        InkWell(
          onTap: () =>
              setState(() => _isComponentsExpanded = !_isComponentsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.widgets_rounded,
                      size: 14,
                      color: VisualEditorTokens.primaryOliveGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'مكتبة المكونات 🧩',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.bold,
                        color: VisualEditorTokens.text(context),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isComponentsExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: VisualEditorTokens.textMuted(context),
                ),
              ],
            ),
          ),
        ),

        // محتوى المكتبة
        if (_isComponentsExpanded) ...[
          // حقل البحث
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _componentSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن مكون…',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: VisualEditorTokens.textMuted(context),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 14),
                isDense: true,
                filled: true,
                fillColor: dark
                    ? VisualEditorTokens.darkSurfaceSecondary
                    : VisualEditorTokens.surfaceSoftCreamSecondary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusSm,
                  ),
                  borderSide: BorderSide(
                    color: VisualEditorTokens.border(context),
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    VisualEditorTokens.radiusSm,
                  ),
                  borderSide: BorderSide(
                    color: VisualEditorTokens.border(context),
                    width: 0.8,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 11),
            ),
          ),

          // تصفية الفئات (الكل، التخطيط، النصوص، الصور)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < categories.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedComponentCategory = i),
                        borderRadius: BorderRadius.circular(
                          VisualEditorTokens.radiusXl,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedComponentCategory == i
                                ? VisualEditorTokens.primaryOliveGreen
                                : (dark
                                      ? VisualEditorTokens.darkSurfaceSecondary
                                      : VisualEditorTokens
                                            .surfaceSoftCreamSecondary),
                            borderRadius: BorderRadius.circular(
                              VisualEditorTokens.radiusXl,
                            ),
                            border: Border.all(
                              color: _selectedComponentCategory == i
                                  ? VisualEditorTokens.primaryOliveGreen
                                  : VisualEditorTokens.border(context),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            categories[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: _selectedComponentCategory == i
                                  ? AppFontWeights.bold
                                  : AppFontWeights.medium,
                              color: _selectedComponentCategory == i
                                  ? Colors.white
                                  : VisualEditorTokens.text(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // مكونات الصفحة الفعلية فقط؛ كل بطاقة قابلة للسحب إلى المعاينة.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final entry in _quickComponentsForPage())
                  _buildQuickComponentCard(
                    context: context,
                    entry: entry,
                    dark: dark,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<ComponentRegistryEntry> _quickComponentsForPage() {
    final query = _componentSearchQuery.trim().toLowerCase();
    return ComponentRegistry.getForPage(widget.selectedPageId).where((entry) {
      final categoryMatches = switch (_selectedComponentCategory) {
        1 => entry.category == 'layout',
        2 =>
          entry.category == 'content' &&
              !entry.properties.values.any(
                (property) => property.type == PropertyType.imageUrl,
              ),
        3 => entry.properties.values.any(
          (property) => property.type == PropertyType.imageUrl,
        ),
        _ => true,
      };
      final searchMatches =
          query.isEmpty ||
          entry.displayName.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query);
      return categoryMatches && searchMatches;
    }).toList();
  }

  Widget _buildQuickComponentCard({
    required BuildContext context,
    required ComponentRegistryEntry entry,
    required bool dark,
  }) {
    final card = Material(
      color: dark
          ? VisualEditorTokens.darkSurfaceSecondary
          : VisualEditorTokens.surfaceSoftCreamSecondary,
      borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
      child: InkWell(
        onTap: () => _addComponent(entry.componentType),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minWidth: 62, maxWidth: 88),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            border: Border.all(
              color: VisualEditorTokens.border(context),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForComponent(entry.componentType),
                size: 16,
                color: VisualEditorTokens.primaryOliveGreen,
              ),
              const SizedBox(height: 3),
              Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: AppFontWeights.medium,
                  color: VisualEditorTokens.text(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<String>(
      data: entry.componentType,
      onDragStarted: () => widget.onDragStateChanged?.call(true),
      onDragEnd: (_) => widget.onDragStateChanged?.call(false),
      feedback: Material(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(entry.displayName),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  void _addComponent(String componentType) {
    final onAddComponent = widget.onAddComponent;
    if (onAddComponent != null) {
      onAddComponent(componentType);
      return;
    }
    final selected = widget.state.selectedComponent;
    final parentId =
        selected != null &&
            selected.pageId == widget.selectedPageId &&
            DesignDocumentCodec.canNest(
              childType: componentType,
              parentType: selected.componentType,
            )
        ? selected.componentId
        : null;
    widget.cubit.addComponent(
      pageId: widget.selectedPageId,
      componentType: componentType,
      parentId: parentId,
    );
  }

  IconData _iconForComponent(String type) => switch (type) {
    'column' => Icons.view_column_outlined,
    'row' => Icons.view_stream_outlined,
    'text' => Icons.text_fields,
    'heading' => Icons.title_rounded,
    'button' || 'welcomeCta' => Icons.smart_button_outlined,
    'image' || 'welcomeHero' || 'bannerCarousel' => Icons.image_outlined,
    'spacer' => Icons.space_bar,
    'divider' => Icons.horizontal_rule,
    'splashSettings' => Icons.tv_rounded,
    _ => Icons.widgets_outlined,
  };
}
