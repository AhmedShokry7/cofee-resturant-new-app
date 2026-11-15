import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// محرك المعاينة الأصلي للمحرر المرئي على المنصات غير الويب.
///
/// على الويب تعرض [PreviewPanel] تطبيق الزبون الحي داخل iframe؛ على
/// ويندوز وماك ولينكس والموبايل لا يوجد iframe، فيرسم هذا المحرك مستند
/// التصميم نفسه بمكوّنات Flutter: نفس التسلسل (القائمة العمقية)، ونفس
/// الخصائص وطبقة الشكل، فما يعدّله الموظف هنا يظهر فورًا.
///
/// القاعدة واحدة مع رسام العميل: خاصية مفقودة أو تالفة تعني قسمًا لا
/// يُرسم — لا انهيار ولا صندوق رمادي. والمحتوى الحقيقي (منتجات/صور)
/// لا يملكه المحرر، فيمثَّل بعناصر توضيحية بنفس الحجم والموضع.
class NativeDesignPreview extends StatelessWidget {
  const NativeDesignPreview({
    super.key,
    required this.components,
    required this.theme,
    this.selectedComponentId,
    required this.onElementSelected,
  });

  /// مكوّنات الصفحة بترتيبها العمقي (القائمة المسطّحة كما في الحالة).
  final List<EditableComponent> components;

  /// طبقة الشكل الحالية للمسودة.
  final DesignTheme theme;

  final String? selectedComponentId;
  final ValueChanged<String> onElementSelected;

  // ---------------------------------------------------------------- الشكل

  Color? _roleColor(DesignColorRole role) {
    final hex = theme.colors[role];
    if (hex == null) return null;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return Color(hex.length == 8 ? value : 0xFF000000 | value);
  }

  double get _textFactor =>
      DesignContract.textFactors[theme.textScale ?? 'default'] ?? 1;

  double _radiusFactor() => switch (theme.radiusScale ?? 'default') {
        'sharp' => 0.5,
        'soft' => 1.25,
        'round' => 1.75,
        'pill' => 3,
        _ => 1,
      };

  double _radius(String? token, {double base = AppRadius.md}) =>
      (switch (token) {
        'none' => 0.0,
        'xs' => AppRadius.xs,
        'sm' => AppRadius.sm,
        'md' => AppRadius.md,
        'lg' => AppRadius.lg,
        'xl' => AppRadius.xl,
        'pill' => AppRadius.pill,
        _ => base,
      }) *
      _radiusFactor();

  double _spacing(String? token, {double fallback = AppSpacing.md}) =>
      switch (token) {
        'none' => AppSpacing.none,
        'xxs' => AppSpacing.xxs,
        'xs' => AppSpacing.xs,
        'sm' => AppSpacing.sm,
        'md' => AppSpacing.md,
        'lg' => AppSpacing.lg,
        'xl' => AppSpacing.xl,
        'xxl' => AppSpacing.xxl,
        'xxxl' => AppSpacing.xxxl,
        _ => fallback,
      };

  Color get _accent => _roleColor(DesignColorRole.primary) ?? AppColor.adminAccent;

  Color get _bg =>
      _roleColor(DesignColorRole.background) ?? AppColor.whiteColor;

  Color get _surface =>
      _roleColor(DesignColorRole.surface) ?? AppColor.lightGreyColor;

  Color get _textPrimary =>
      _roleColor(DesignColorRole.textPrimary) ?? AppColor.adminBody;

  Color get _textSecondary =>
      _roleColor(DesignColorRole.textSecondary) ?? AppColor.adminMuted;

  Color get _borderColor =>
      _roleColor(DesignColorRole.border) ?? AppColor.adminControlBorder;

  // ---------------------------------------------------------------- الشجرة

  Map<String, List<EditableComponent>> get _childrenByParent {
    final byParent = <String, List<EditableComponent>>{};
    for (final component in components) {
      final parent = component.parentId;
      if (parent == null) continue;
      (byParent[parent] ??= []).add(component);
    }
    byParent.forEach((_, children) {
      children.sort((a, b) => a.index.compareTo(b.index));
    });
    return byParent;
  }

  @override
  Widget build(BuildContext context) {
    final byParent = _childrenByParent;
    final roots = components
        .where((c) => c.parentId == null)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final sections = <Widget>[];
    for (final root in roots) {
      final child = _render(root, byParent);
      if (child == null) continue;
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: AppSpacing.sm));
      }
      sections.add(child);
    }
    return ColoredBox(
      color: _bg,
      child: sections.isEmpty
          ? Center(
              child: Text(
                'لا توجد أقسام في هذه الصفحة',
                style: TextStyle(
                  fontSize: AppFontSizes.size12 * _textFactor,
                  color: _textSecondary,
                ),
              ),
            )
          // المعاينة الأصلية تمرر محتواها داخل الشاشة كما يفعل التطبيق
          // الحقيقي، بدل القصّ حين يتجاوز المحتوى ارتفاع الجهاز.
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sections,
              ),
            ),
    );
  }

  /// رسم عقدة واحدة بأبنائها، أو null لما لا يرسم (مخفي أو نوع تالف).
  Widget? _render(
    EditableComponent component,
    Map<String, List<EditableComponent>> byParent,
  ) {
    if (component.properties['visible'] == false) return null;
    final Widget? content;
    switch (component.componentType) {
      case 'header':
        content = _header(component);
      case 'searchBar':
        content = _searchBar(component);
      case 'bannerCarousel':
        content = _bannerCarousel(component);
      case 'categoryList':
        content = _categoryList(component);
      case 'promoBanner':
        content = _promoBanner(component);
      case 'productStrip':
        content = _productStrip(component);
      case 'productGrid':
        content = _productGrid(component);
      case 'bundleList':
        content = _bundleList(component);
      case 'text':
        content = _text(component);
      case 'heading':
        content = _heading(component);
      case 'button':
        content = _button(component);
      case 'image':
        content = _image(component);
      case 'divider':
        content = _divider(component);
      case 'spacer':
        content = _spacer(component);
      case 'column':
        content = _column(component, byParent);
      default:
        return null;
    }
    final selected = component.componentId == selectedComponentId;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onElementSelected(component.componentId),
      child: Container(
        decoration: selected
            ? BoxDecoration(
                border: Border.all(color: _accent, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              )
            : null,
        child: content,
      ),
    );
  }

  // ---------------------------------------------------------------- الأقسام

  Widget _header(EditableComponent c) {
    final showSearch = c.properties['showSearch'] as bool? ?? true;
    final showGreeting = c.properties['showGreeting'] as bool? ?? true;
    return Container(
      color: _surface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGreeting)
            Text(
              'أهلًا بك في كوفي ☕',
              style: TextStyle(
                fontSize: AppFontSizes.size16 * _textFactor,
                fontWeight: AppFontWeights.bold,
                color: _textPrimary,
              ),
            ),
          if (showSearch) ...[
            const SizedBox(height: AppSpacing.sm),
            _searchField('ابحث عن منتج...'),
          ],
        ],
      ),
    );
  }

  Widget _searchBar(EditableComponent c) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: _searchField(
          (c.properties['hint'] as String?) ?? 'ابحث عن منتج...',
        ),
      );

  Widget _searchField(String hint) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(_radius('pill')),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Icon(AppIcons.search01, size: 16, color: _textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: AppFontSizes.size12 * _textFactor,
                  color: _textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _bannerCarousel(EditableComponent c) {
    final height = (c.properties['height'] as num?)?.toDouble() ?? 184.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent, _accent.withAlpha(120)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(_radius(c.property('radius'))),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.promotion, size: 28, color: Colors.white),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'عرض اليوم',
              style: TextStyle(
                fontSize: AppFontSizes.size14 * _textFactor,
                fontWeight: AppFontWeights.semiBold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoBanner(EditableComponent c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: _roleColor(DesignColorRole.secondary) ?? _accent,
            borderRadius: BorderRadius.circular(_radius(c.property('radius'))),
          ),
          alignment: Alignment.center,
          child: Text(
            'إعلان ترويجي',
            style: TextStyle(
              fontSize: AppFontSizes.size13 * _textFactor,
              fontWeight: AppFontWeights.semiBold,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _sectionTitle(String? raw, {required bool show}) {
    if (!show || raw == null || raw.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              raw,
              style: TextStyle(
                fontSize: AppFontSizes.size14 * _textFactor,
                fontWeight: AppFontWeights.semiBold,
                color: _textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_left, size: 16, color: _textSecondary),
        ],
      ),
    );
  }

  Widget _categoryList(EditableComponent c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            c.property('title'),
            show: c.properties['showTitle'] as bool? ?? true,
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: 8,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, index) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _surface,
                    child: Icon(AppIcons.folder01, size: 20, color: _accent),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SizedBox(
                    width: 52,
                    child: Text(
                      'تصنيف ${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppFontSizes.size9_5 * _textFactor,
                        color: _textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _productCard({bool showPrice = true, double? width}) => Container(
        width: width ?? 120,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_radius('md')),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(_radius('sm')),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.shoppingBag01,
                  size: 24,
                  color: _textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              height: 9,
              width: 64,
              decoration: BoxDecoration(
                color: _textSecondary.withAlpha(70),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            if (showPrice) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '12.500 د.ك',
                style: TextStyle(
                  fontSize: AppFontSizes.size10 * _textFactor,
                  fontWeight: AppFontWeights.semiBold,
                  color: _accent,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _productStrip(EditableComponent c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            c.property('title'),
            show: true,
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount:
                  (((c.properties['maxItems'] as num?) ?? 10).clamp(1, 50))
                      .toInt(),
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, _) => _productCard(
                showPrice: c.properties['showPrice'] as bool? ?? true,
              ),
            ),
          ),
        ],
      );

  Widget _productGrid(EditableComponent c) {
    final columns = ((c.properties['columns'] as num?) ?? 2).clamp(1, 4);
    final maxItems = ((c.properties['maxItems'] as num?) ?? 20).clamp(1, 100);
    final rows = (maxItems / columns).ceil().clamp(1, 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(c.property('title'), show: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (var row = 0; row < rows; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      for (var col = 0; col < columns; col++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: col < columns - 1 ? AppSpacing.sm : 0,
                            ),
                            child: SizedBox(
                              height: 150,
                              child: _productCard(
                                showPrice:
                                    c.properties['showPrice'] as bool? ?? true,
                                width: double.infinity,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bundleList(EditableComponent c) {
    final isList = c.property('layout') == 'list';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          c.property('title'),
          show: c.properties['showTitle'] as bool? ?? true,
        ),
        SizedBox(
          height: isList ? 3 * 56 : 120,
          child: isList
              ? Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: _bundleTile(),
                      ),
                  ],
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: 4,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, _) => _bundleTile(width: 150),
                ),
        ),
      ],
    );
  }

  Widget _bundleTile({double? width}) => Container(
        width: width,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(_radius('md')),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accent.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.cube, size: 18, color: _accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 9,
                    width: 80,
                    decoration: BoxDecoration(
                      color: _textSecondary.withAlpha(70),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '3 أصناف',
                    style: TextStyle(
                      fontSize: AppFontSizes.size9_5 * _textFactor,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _text(EditableComponent c) {
    final text = (c.properties['text'] as String?) ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    final size = double.tryParse((c.properties['size'] as String?) ?? '14') ??
        14.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(
        text,
        textAlign: switch (c.property('alignment')) {
          'center' => TextAlign.center,
          'end' => TextAlign.end,
          _ => TextAlign.start,
        },
        style: TextStyle(
          fontSize: size * _textFactor,
          fontWeight: _weight(c.property('weight')),
          color: _hex(c.property('color')) ?? _textPrimary,
          height: (c.properties['lineHeight'] as num?)?.toDouble() ?? 1.4,
        ),
        maxLines: (c.properties['maxLines'] as num?)?.toInt(),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _heading(EditableComponent c) {
    final title = (c.properties['title'] as String?) ?? '';
    final subtitle = (c.properties['subtitle'] as String?) ?? '';
    final linkLabel = (c.properties['linkLabel'] as String?) ?? '';
    if (title.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();
    final titleSize =
        double.tryParse((c.properties['titleSize'] as String?) ?? '16') ?? 16.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: titleSize * _textFactor,
                fontWeight: AppFontWeights.bold,
                color: _textPrimary,
              ),
            ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppFontSizes.size11 * _textFactor,
                color: _textSecondary,
              ),
            ),
          ],
          if (linkLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$linkLabel ←',
              style: TextStyle(
                fontSize: AppFontSizes.size11 * _textFactor,
                fontWeight: AppFontWeights.medium,
                color: _accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _button(EditableComponent c) {
    final label = (c.properties['label'] as String?) ?? '';
    if (label.isEmpty) return const SizedBox.shrink();
    final style = c.property('style') ?? 'primary';
    final bg = _hex(c.property('color')) ?? _accent;
    final fg = _hex(c.property('textColor')) ?? Colors.white;
    final hasIcon = ((c.properties['icon'] as String?) ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: 40,
        child: Material(
          color: style == 'primary' ? bg : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              _radius(c.property('borderRadius'), base: AppRadius.sm),
            ),
            side: style == 'outline' ? BorderSide(color: bg) : BorderSide.none,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIcon) ...[
                  Icon(Icons.touch_app, size: 14, color: fg),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFontSizes.size12 * _textFactor,
                    fontWeight: AppFontWeights.semiBold,
                    color: style == 'text' ? bg : fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(EditableComponent c) {
    final url = (c.properties['imageUrl'] as String?) ?? '';
    final height = (c.properties['height'] as num?)?.toDouble() ?? 160.0;
    Widget child;
    if (url.isEmpty) {
      child = Container(
        height: height,
        color: _surface,
        alignment: Alignment.center,
        child: Icon(AppIcons.image01, size: 28, color: _textSecondary),
      );
    } else {
      child = Image.network(
        url,
        height: height,
        fit: c.property('fit') == 'contain' ? BoxFit.contain : BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: height,
          color: _surface,
          alignment: Alignment.center,
          child: Icon(AppIcons.image01, size: 28, color: _textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          _radius(c.property('borderRadius'), base: AppRadius.sm),
        ),
        child: child,
      ),
    );
  }

  Widget _divider(EditableComponent c) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _spacing(c.property('inset')),
        ),
        child: Divider(
          thickness: (c.properties['thickness'] as num?)?.toDouble() ?? 1,
          color: _hex(c.property('color')) ?? _borderColor,
        ),
      );

  Widget _spacer(EditableComponent c) =>
      SizedBox(height: _spacing(c.property('size'), fallback: AppSpacing.lg));

  Widget _column(
    EditableComponent c,
    Map<String, List<EditableComponent>> byParent,
  ) {
    final children = byParent[c.componentId] ?? const [];
    final rendered = <Widget>[];
    for (final child in children) {
      final widget = _render(child, byParent);
      if (widget == null) continue;
      if (rendered.isNotEmpty) {
        rendered.add(SizedBox(height: _spacing(c.property('gap'))));
      }
      rendered.add(widget);
    }
    if (rendered.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _spacing(c.property('inset')),
      ),
      child: Column(
        crossAxisAlignment: switch (c.property('crossAxisAlignment')) {
          'center' => CrossAxisAlignment.center,
          'end' => CrossAxisAlignment.end,
          'stretch' => CrossAxisAlignment.stretch,
          _ => CrossAxisAlignment.start,
        },
        children: rendered,
      ),
    );
  }

  // ---------------------------------------------------------------- أدوات

  static FontWeight _weight(String? name) => switch (name) {
        'bold' => AppFontWeights.bold,
        'semibold' => AppFontWeights.semiBold,
        'medium' => AppFontWeights.medium,
        _ => AppFontWeights.regular,
      };

  static Color? _hex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return Color(hex.length == 8 ? value : 0xFF000000 | value);
  }
}

extension on EditableComponent {
  /// خاصية كنص، مع قيم مفقودة تعود لقيمتها الافتراضية في السجل.
  String? property(String key) {
    final value = properties[key];
    if (value is String && value.isNotEmpty) return value;
    return defaultValues[key]?.toString();
  }
}
