import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';

/// لوحة شجرة المكوّنات — تعرض المكوّنات المسجلة في الصفحة المحددة
/// وتتيح تحديدها وإعادة ترتيبها وإخفاءها وحذفها.
/// يحوّل موضع الإدراج في القائمة المسطّحة إلى فهرس الإخوة؛ فالـ Cubit
/// يعيد الترتيب داخل أبناء الأب نفسه فقط.
int siblingIndexForFlatReorder({
  required List<EditableComponent> components,
  required int oldIndex,
  required int newIndex,
}) {
  final moving = components[oldIndex];
  return components.asMap().entries.where((entry) {
    if (entry.key == oldIndex || entry.value.parentId != moving.parentId) {
      return false;
    }
    final indexAfterRemoval = entry.key > oldIndex ? entry.key - 1 : entry.key;
    return indexAfterRemoval < newIndex;
  }).length;
}

/// أنواع العناصر القابلة للإضافة السريعة من شريط الإضافة
const _quickAddTypes = [
  ('text', 'نص', Icons.text_fields),
  ('heading', 'عنوان', Icons.title),
  ('button', 'زر', Icons.smart_button_outlined),
  ('image', 'صورة', Icons.image_outlined),
  ('spacer', 'مسافة', Icons.space_bar),
  ('divider', 'فاصل', Icons.horizontal_rule),
];

/// استخراج نص معاينة من خصائص المكوّن حسب نوعه
String? _imagePreviewUrl(EditableComponent component) {
  final properties = component.properties;
  final directUrl = properties['imageUrl'] ?? properties['image_url'];
  if (directUrl is String && directUrl.trim().isNotEmpty) {
    return directUrl.trim();
  }

  return null;
}

String _previewText(EditableComponent c) {
  final p = c.properties;
  switch (c.componentType) {
    case 'text':
      final ar = p['text_ar'];
      if (ar is String && ar.isNotEmpty) return ar;
      final en = p['text_en'];
      if (en is String && en.isNotEmpty) return en;
      final legacy = p['text'];
      if (legacy is String && legacy.isNotEmpty) return legacy;
      return 'نص فارغ';

    case 'heading':
      final ar = p['title_ar'];
      if (ar is String && ar.isNotEmpty) return ar;
      final en = p['title_en'];
      if (en is String && en.isNotEmpty) return en;
      final legacy = p['title'];
      if (legacy is String && legacy.isNotEmpty) return legacy;
      return 'عنوان فارغ';

    case 'button':
      final ar = p['label_ar'];
      if (ar is String && ar.isNotEmpty) return ar;
      final en = p['label_en'];
      if (en is String && en.isNotEmpty) return en;
      return 'زر';

    case 'image':
      final url = p['imageUrl'] ?? p['url'];
      if (url is String && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
        }
        return url;
      }
      return 'صورة';

    case 'spacer':
      final size = p['size'] ?? p['height'];
      if (size != null) return 'ارتفاع: ${size}px';
      return 'مسافة';

    case 'divider':
      return 'خط فاصل';

    case 'header':
      final title = p['title_ar'] ?? p['title'];
      if (title is String && title.isNotEmpty) return title;
      return 'شريط التطبيق';

    case 'searchBar':
      final hint = p['hint_ar'] ?? p['hint'];
      if (hint is String && hint.isNotEmpty) return hint;
      return 'شريط البحث';

    case 'bannerCarousel':
      return 'بانر متحرك';

    case 'categoryList':
      final title = p['title_ar'] ?? p['title'];
      if (title is String && title.isNotEmpty) return title;
      return 'قائمة الفئات';

    case 'productStrip':
      final src = p['dataSource'];
      if (src == 'featured') return 'المنتجات المميزة';
      if (src == 'recommendations') return 'المنتجات المقترحة';
      if (src is String && src.isNotEmpty) return src;
      return 'شريط المنتجات';

    case 'productGrid':
      return 'شبكة المنتجات';

    case 'promoBanner':
      final title = p['title_ar'] ?? p['title'];
      if (title is String && title.isNotEmpty) return title;
      return 'بانر عرض';

    case 'bundleList':
      return 'قائمة الحزم';

    case 'splashSettings':
      return 'إعدادات الافتتاحية';

    case 'welcomeHero':
      return 'صورة الترحيب';

    case 'welcomeTitle':
      final ar = p['text_ar'] ?? p['text'];
      if (ar is String && ar.isNotEmpty) return ar;
      return 'عنوان الترحيب';

    case 'welcomeBody':
      final ar = p['text_ar'] ?? p['text'];
      if (ar is String && ar.isNotEmpty) return ar;
      return 'نص الترحيب';

    case 'welcomeSpacing':
      return 'مسافة الترحيب';

    case 'welcomeCta':
      final label = p['label_ar'] ?? p['label'];
      if (label is String && label.isNotEmpty) return label;
      return 'زر الترحيب';

    case 'onboardingSlide':
      final title = p['title_ar'] ?? p['title'];
      if (title is String && title.isNotEmpty) return title;
      return 'شريحة تعريفية';

    case 'onboardingTransition':
      return 'انتقال Onboarding';

    case 'authTitle':
      final ar = p['text_ar'] ?? p['text'];
      if (ar is String && ar.isNotEmpty) return ar;
      return 'عنوان الدخول';

    case 'authSubtitle':
      final ar = p['text_ar'] ?? p['text'];
      if (ar is String && ar.isNotEmpty) return ar;
      return 'وصف الدخول';

    case 'authSocial':
      return 'أزرار الدخول الاجتماعي';

    case 'authSwitchPrompt':
      return 'رابط التبديل (تسجيل/دخول)';

    default:
      return c.componentType;
  }
}

/// لون أيقونة حسب نوع المكوّن
Color _colorForType(String type, {bool selected = false, required bool dark}) {
  if (selected) return const Color(0xFF5A6A3A); // olive green
  return switch (type) {
    'text' => const Color(0xFF2563EB), // أزرق — نص
    'heading' => const Color(0xFF7C3AED), // بنفسجي — عنوان
    'button' => const Color(0xFF059669), // أخضر — زر
    'image' => const Color(0xFFD97706), // برتقالي — صورة
    'spacer' => const Color(0xFF9CA3AF), // رمادي — مسافة
    'divider' => const Color(0xFF6B7280), // رمادي غامق — فاصل
    'header' => const Color(0xFF1D4ED8), // أزرق غامق — شريط التطبيق
    'searchBar' => const Color(0xFF0891B2), // سماوي — بحث
    'bannerCarousel' => const Color(0xFFB45309), // بني — بانر
    'categoryList' => const Color(0xFF4F46E5), // بنفسجي — فئات
    'productStrip' => const Color(0xFFB91C1C), // أحمر — منتجات
    'productGrid' => const Color(0xFFB91C1C), // أحمر — منتجات
    'promoBanner' => const Color(0xFFD97706), // برتقالي — عروض
    'bundleList' => const Color(0xFF0F766E), // أخضر مزرق — حزم
    _ => dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
  };
}

class ComponentTreePanel extends StatefulWidget {
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
    this.onAddComponent,
  });

  final String pageId;
  final List<EditableComponent> components;
  final String? selectedComponentId;
  final void Function(String componentId) onSelect;
  final void Function(String componentId, int newIndex) onReorder;
  final void Function(String componentId) onDelete;
  final void Function(String componentId) onDuplicate;
  final void Function(String componentId) onToggleVisibility;
  final void Function(String componentType)? onAddComponent;

  @override
  State<ComponentTreePanel> createState() => _ComponentTreePanelState();
}

class _ComponentTreePanelState extends State<ComponentTreePanel> {
  String _searchQuery = '';
  bool _showQuickAdd = false;

  List<EditableComponent> get _filtered {
    if (_searchQuery.trim().isEmpty) return widget.components;
    final q = _searchQuery.trim().toLowerCase();
    return widget.components.where((c) {
      final entry = ComponentRegistry.get(c.componentType);
      final name = (entry?.displayName ?? c.componentType).toLowerCase();
      final preview = _previewText(c).toLowerCase();
      final id = c.componentId.toLowerCase();
      return name.contains(q) || preview.contains(q) || id.contains(q);
    }).toList();
  }

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
          // ترويسة اللوحة مع زر الإضافة
          _PanelHeader(
            icon: AppIcons.layers01,
            title: S.visualEditorLayers,
            onAddTap: () => setState(() => _showQuickAdd = !_showQuickAdd),
            isAddActive: _showQuickAdd,
          ),
          const Divider(height: 1),

          // شريط البحث
          _SearchBar(
            query: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
            dark: dark,
          ),

          // شريط الإضافة السريعة
          if (_showQuickAdd) ...[
            const Divider(height: 1),
            _QuickAddBar(
              pageId: widget.pageId,
              onAdd: (type) {
                widget.onAddComponent?.call(type);
                setState(() => _showQuickAdd = false);
              },
              dark: dark,
            ),
          ],

          const Divider(height: 1),

          // عداد العناصر
          _CountBar(
            total: widget.components.length,
            filtered: _filtered.length,
            isFiltering: _searchQuery.isNotEmpty,
            dark: dark,
          ),

          // قائمة العناصر
          Expanded(
            child: _filtered.isEmpty
                ? (_searchQuery.isEmpty
                      ? AdminEmptyState(
                          icon: AppIcons.layers01,
                          message: S.visualEditorNoComponents,
                        )
                      : _EmptySearch(query: _searchQuery, dark: dark))
                : _ComponentList(
                    components: _filtered,
                    allComponents: widget.components,
                    selectedComponentId: widget.selectedComponentId,
                    onSelect: widget.onSelect,
                    onReorder: widget.onReorder,
                    onDelete: widget.onDelete,
                    onDuplicate: widget.onDuplicate,
                    onToggleVisibility: widget.onToggleVisibility,
                    allowReorder: _searchQuery.trim().isEmpty,
                    dark: dark,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── شريط البحث ───────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.query,
    required this.onChanged,
    required this.dark,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'ابحث في العناصر…',
          hintStyle: TextStyle(
            fontSize: 11.5,
            color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
          ),
          suffixIcon: query.isNotEmpty
              ? GestureDetector(
                  onTap: () => onChanged(''),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: dark
                        ? AppColor.darkTextSecondary
                        : AppColor.adminMuted,
                  ),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: Color(0xFF5A6A3A)),
          ),
          filled: true,
          fillColor: dark
              ? AppColor.darkSurfaceContainer
              : const Color(0xFFF9F7F4),
        ),
        style: TextStyle(
          fontSize: 12,
          color: dark ? AppColor.darkText : AppColor.adminBody,
        ),
      ),
    );
  }
}

// ─────────────────────────── عداد العناصر ───────────────────────────

class _CountBar extends StatelessWidget {
  const _CountBar({
    required this.total,
    required this.filtered,
    required this.isFiltering,
    required this.dark,
  });

  final int total;
  final int filtered;
  final bool isFiltering;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final label = isFiltering ? '$filtered من $total عنصر' : '$total عنصر';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 3,
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: muted)),
    );
  }
}

// ─────────────────────────── شريط الإضافة السريعة ───────────────────────────

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.pageId,
    required this.onAdd,
    required this.dark,
  });

  final String pageId;
  final void Function(String) onAdd;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dark ? AppColor.darkSurfaceContainer : const Color(0xFFF5F3EF),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'إضافة عنصر جديد',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: AppFontWeights.semiBold,
                color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (type, label, icon) in _quickAddTypes)
                _QuickAddChip(
                  label: label,
                  icon: icon,
                  onTap: () => onAdd(type),
                  dark: dark,
                  color: _colorForType(type, dark: dark),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.dark,
    required this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFontWeights.medium,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── حالة البحث الفارغ ───────────────────────────

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query, required this.dark});

  final String query;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 32,
            color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'لا نتائج لـ "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── قائمة العناصر ───────────────────────────

class _ComponentList extends StatelessWidget {
  const _ComponentList({
    required this.components,
    required this.allComponents,
    required this.selectedComponentId,
    required this.onSelect,
    required this.onReorder,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleVisibility,
    required this.allowReorder,
    required this.dark,
  });

  final List<EditableComponent> components;
  final List<EditableComponent> allComponents;
  final String? selectedComponentId;
  final void Function(String) onSelect;
  final void Function(String, int) onReorder;
  final void Function(String) onDelete;
  final void Function(String) onDuplicate;
  final void Function(String) onToggleVisibility;
  final bool allowReorder;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      buildDefaultDragHandles: false,
      itemCount: components.length,
      onReorderItem: (oldIndex, newIndex) {
        if (!allowReorder) return;
        final component = components[oldIndex];
        final siblingIndex = siblingIndexForFlatReorder(
          components: allComponents,
          oldIndex: allComponents.indexWhere(
            (c) => c.componentId == component.componentId,
          ),
          newIndex: newIndex,
        );
        onReorder(component.componentId, siblingIndex);
      },
      itemBuilder: (context, index) {
        final component = components[index];
        return _ComponentRow(
          key: ValueKey(component.componentId),
          component: component,
          index: index,
          isSelected: component.componentId == selectedComponentId,
          onTap: () => onSelect(component.componentId),
          onDelete: component.canDelete
              ? () => onDelete(component.componentId)
              : null,
          onDuplicate: component.canDuplicate
              ? () => onDuplicate(component.componentId)
              : null,
          onToggleVisibility: () => onToggleVisibility(component.componentId),
          allowReorder: allowReorder,
          dark: dark,
        );
      },
    );
  }
}

// ─────────────────────────── صف مكوّن ───────────────────────────

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    super.key,
    required this.component,
    required this.index,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onDuplicate,
    required this.onToggleVisibility,
    required this.allowReorder,
    required this.dark,
  });

  final EditableComponent component;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback onToggleVisibility;
  final bool allowReorder;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final isVisible = component.properties['visible'] as bool? ?? true;
    final entry = ComponentRegistry.get(component.componentType);
    final isChild = component.parentId != null;
    final typeColor = _colorForType(
      component.componentType,
      selected: isSelected,
      dark: dark,
    );

    final selectedBg = dark
        ? AppColor.darkSurfaceContainer
        : const Color(0xFFEEF2E8); // olive tint
    final rowBg = isSelected ? selectedBg : Colors.transparent;

    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final bodyColor = dark ? AppColor.darkText : AppColor.adminBody;

    final previewStr = _previewText(component);
    final imagePreviewUrl = _imagePreviewUrl(component);

    return Material(
      color: rowBg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Opacity(
          opacity: isVisible ? 1.0 : 0.45,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: isChild ? AppSpacing.md + AppSpacing.sm : AppSpacing.sm,
              end: AppSpacing.xs,
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                // ► مؤشر التداخل (أبناء)
                if (isChild)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 12,
                      color: muted,
                    ),
                  ),

                // ► مقبض السحب
                if (component.canReorder && allowReorder)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Icon(Icons.drag_indicator, size: 15, color: muted),
                    ),
                  )
                else
                  SizedBox(width: AppSpacing.sm + 4),

                // ► شريط اللون الجانبي
                Container(
                  width: 3,
                  height: 32,
                  margin: const EdgeInsetsDirectional.only(end: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? typeColor
                        : typeColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ► صورة مصغرة للعناصر ذات الصورة، وأيقونة النوع للباقي
                if (imagePreviewUrl != null)
                  AdminNetworkThumb(
                    imageUrl: imagePreviewUrl,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    icon: _iconForType(component.componentType),
                  )
                else
                  Icon(
                    _iconForType(component.componentType),
                    size: 15,
                    color: typeColor,
                  ),
                const SizedBox(width: 6),

                // ► الاسم والمعاينة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry?.displayName ?? component.componentType,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? AppFontWeights.semiBold
                              : AppFontWeights.medium,
                          color: isSelected ? typeColor : bodyColor,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        previewStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: muted,
                          height: 1.3,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ► أزرار الإجراءات (تظهر عند التحويم أو التحديد)
                _ActionButton(
                  icon: isVisible ? AppIcons.eyeIcon : AppIcons.eyeOff,
                  tooltip: isVisible ? S.visualEditorHide : S.visualEditorShow,
                  color: isVisible ? muted : const Color(0xFF5A6A3A),
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
                  PopupMenuButton<String>(
                    tooltip: S.visualEditorMoreActions,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    onSelected: (action) {
                      if (action == 'delete') onDelete!();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.delete01,
                              size: 16,
                              color: AppColor.errorColor,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              S.visualEditorDelete,
                              style: TextStyle(color: AppColor.errorColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
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
      'button' => Icons.smart_button_outlined,
      'image' => AppIcons.image01,
      'divider' => Icons.horizontal_rule,
      'spacer' => Icons.space_bar,
      'column' => Icons.view_column,
      'row' => Icons.table_rows_outlined,
      'splashSettings' => Icons.tv_rounded,
      'welcomeHero' => Icons.photo_size_select_actual_outlined,
      'welcomeTitle' => Icons.title,
      'welcomeBody' => Icons.text_fields,
      'welcomeSpacing' => Icons.space_bar,
      'welcomeCta' => Icons.smart_button_outlined,
      'onboardingSlide' => Icons.slideshow_rounded,
      'onboardingTransition' => Icons.animation_rounded,
      'authTitle' => Icons.title,
      'authSubtitle' => Icons.text_fields,
      'authSocial' => Icons.login_rounded,
      'authSwitchPrompt' => Icons.swap_horiz_rounded,
      _ => AppIcons.layers01,
    };
  }
}

// ─────────────────────────── زر إجراء ───────────────────────────

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

// ─────────────────────────── ترويسة اللوحة ───────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.onAddTap,
    this.isAddActive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onAddTap;
  final bool isAddActive;

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
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFontWeights.semiBold,
                color: heading,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // زر الإضافة السريعة
          if (onAddTap != null)
            Tooltip(
              message: 'إضافة عنصر',
              child: InkWell(
                onTap: onAddTap,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isAddActive
                        ? const Color(0xFF5A6A3A).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: isAddActive
                        ? Border.all(
                            color: const Color(0xFF5A6A3A)
                                .withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Icon(
                    isAddActive ? Icons.close_rounded : Icons.add_rounded,
                    size: 16,
                    color: isAddActive ? const Color(0xFF5A6A3A) : muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
