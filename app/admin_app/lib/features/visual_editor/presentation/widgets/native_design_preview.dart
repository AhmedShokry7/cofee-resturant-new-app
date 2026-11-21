import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';

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
    this.screenSize,
    this.previewLanguage,
    this.previewThemeMode,
    this.publishedBannerImages = const [],
    required this.onElementSelected,
  });

  /// مكوّنات الصفحة بترتيبها العمقي (القائمة المسطّحة كما في الحالة).
  final List<EditableComponent> components;

  /// طبقة الشكل الحالية للمسودة.
  final DesignTheme theme;

  final String? selectedComponentId;
  final Size? screenSize;

  /// اللغة والوضع المختاران لمعاينة تطبيق العميل. الغياب يعني ما كانت اللوحة
  /// تعرضه قبل إضافة أدوات المعاينة، فلا تتغيّر اختبارات المعاينة الأصلية.
  final PreviewLanguage? previewLanguage;
  final PreviewThemeMode? previewThemeMode;

  /// Customer banners shown until the editor document starts an explicit draft.
  final List<String> publishedBannerImages;

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
        'xl' => 24.0,
        'xxl' => 32.0,
        'xxxl' => 48.0,
        _ => fallback,
      };

  PreviewLanguage get _effectiveLanguage =>
      previewLanguage ??
      (AppLocale.instance.isArabic
          ? PreviewLanguage.arabic
          : PreviewLanguage.english);

  bool get _darkPreview => previewThemeMode == PreviewThemeMode.dark;

  Color get _accent =>
      _roleColor(DesignColorRole.primary) ?? AppColor.adminAccent;

  Color get _bg =>
      _roleColor(DesignColorRole.background) ??
      (_darkPreview ? AppColor.darkBackground : AppColor.whiteColor);

  Color get _surface =>
      _roleColor(DesignColorRole.surface) ??
      (_darkPreview ? AppColor.darkSurface : AppColor.lightGreyColor);

  Color get _textPrimary =>
      _roleColor(DesignColorRole.textPrimary) ??
      (_darkPreview ? AppColor.darkText : AppColor.adminBody);

  Color get _textSecondary =>
      _roleColor(DesignColorRole.textSecondary) ??
      (_darkPreview ? AppColor.darkTextSecondary : AppColor.adminMuted);

  Color get _borderColor =>
      _roleColor(DesignColorRole.border) ??
      (_darkPreview ? Color(0xff3A3A3A) : AppColor.adminControlBorder);

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
    final roots = components.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    // The customer welcome page is a layered screen: its image sits behind an
    // organic panel. Rendering its nodes as a vertical list made the fallback
    // preview look unlike the page users are editing.
    if (roots.any((component) => component.componentType == 'welcomeHero')) {
      return _welcomePage(context, roots, byParent);
    }
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

  Widget _welcomePage(
    BuildContext context,
    List<EditableComponent> roots,
    Map<String, List<EditableComponent>> byParent,
  ) {
    final size = screenSize ?? MediaQuery.sizeOf(context);
    EditableComponent? find(String type) {
      for (final component in roots) {
        if (component.componentType == type) return component;
      }
      return null;
    }

    final hero = find('welcomeHero');
    final spacing = find('welcomeSpacing');
    final visible = roots
        .where((component) =>
            component.componentType != 'welcomeHero' &&
            component.componentType != 'welcomeSpacing' &&
            component.properties['visible'] != false)
        .toList();
    final defaultRatio = size.height < 720 ? 0.62 : 0.63;
    final imageHeight = size.height *
        (hero == null ? defaultRatio : (_numProp(hero, 'heightRatio') ?? defaultRatio))
            .clamp(0.25, 0.85);
    final curveDepth =
        (spacing == null ? 55.0 : (_numProp(spacing, 'curveDepth') ?? 55))
            .clamp(0.0, 140.0);
    final panelColor = _hexColor(spacing?.property('panelColor')) ?? Colors.white;
    final horizontal = spacing == null
        ? 32.0
        : (_numProp(spacing, 'paddingHorizontal') ?? 32.0);
    final top = spacing == null ? 20.0 : (_numProp(spacing, 'top') ?? 20.0);
    final bottom = spacing == null
        ? 32.0
        : (_numProp(spacing, 'paddingBottom') ?? 32.0);
    final gap = spacing == null
        ? AppSpacing.md
        : (_numProp(spacing, 'gap') ?? AppSpacing.md);
    final alignment = switch (spacing?.property('contentAlignment')) {
      'start' => MainAxisAlignment.start,
      'center' => MainAxisAlignment.center,
      _ => MainAxisAlignment.end,
    };

    return SizedBox(
      width: double.infinity,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (hero != null && hero.properties['visible'] != false)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight,
              child: _render(hero, byParent) ?? const SizedBox.shrink(),
            ),
          Positioned(
            top: imageHeight - curveDepth,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: _WelcomePanelClipper(curveDepth),
              child: ColoredBox(
                color: panelColor,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: alignment,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < visible.length; i++) ...[
                                if (i > 0 && visible[i - 1].componentType == 'welcomeTitle')
                                  SizedBox(height: gap),
                                if (_render(visible[i], byParent) case final widget?)
                                  widget,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// رسم عقدة واحدة بأبنائها، أو null لما لا يرسم (مخفي أو نوع تالف).
  Widget? _render(
    EditableComponent component,
    Map<String, List<EditableComponent>> byParent,
  ) {
    if (component.properties['visible'] == false) return null;
    late Widget content;
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
      case 'row':
        content = _row(component, byParent);
      // عقد الشاشات المدمجة: تقرؤها شاشات العميل نفسها لا محرك الأقسام،
      // فترسمها المعاينة الأصلية بنفس ما تعرضه الشاشة من صورة ونصّ، حتى
      // يرى الموظف تعديله فورًا بلا انتظار بناء الويب.
      case 'splashSettings':
        content = Builder(
          builder: (context) => _splashSettings(component, context),
        );
      case 'welcomeHero':
        content = _welcomeHero(component);
      case 'welcomeTitle':
        content = _welcomeTitle(component);
      case 'welcomeBody':
        content = _text(component);
      case 'welcomeSpacing':
        content = _welcomeSpacing(component);
      case 'welcomeCta':
        content = _welcomeCta(component);
      case 'onboardingSlide':
        content = _onboardingSlide(component);
      case 'onboardingTransition':
        content = _onboardingTransition(component);
      case 'authTitle':
      case 'authSubtitle':
        content = _text(component);
      case 'authSocial':
        content = _authSocial();
      case 'authSwitchPrompt':
        content = _authSwitchPrompt();
      default:
        // Keep every node visible in the local preview. Silently dropping an
        // unimplemented registry type made pages look incomplete and gave no
        // clue why a layer was missing from the device.
        content = _unsupportedComponent(component);
    }
    // Apply DesignSectionChrome-like styling to all components
    content = _applyChrome(component, content);

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
    final greetingText = _locOr(c, 'greeting', 'أهلًا بك في كوفي ☕');
    final questionText = _loc(c, 'question');
    return Container(
      color: _surface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGreeting) ...[
            Text(
              greetingText,
              style: TextStyle(
                fontSize: AppFontSizes.size16 * _textFactor,
                fontWeight: AppFontWeights.bold,
                color: _textPrimary,
              ),
            ),
            if (questionText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                questionText,
                style: TextStyle(
                  fontSize: AppFontSizes.size12 * _textFactor,
                  color: _textSecondary,
                ),
              ),
            ],
          ],
          if (showSearch) ...[
            const SizedBox(height: AppSpacing.sm),
            _searchField(_locOr(c, 'hint', 'ابحث عن منتج...')),
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
    child: _searchField(_locOr(c, 'hint', 'ابحث عن منتج...')),
  );

  Widget _searchField(String hint) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(_radius('pill')),
      border: Border.all(color: _borderColor),
    ),
    child: Row(
      children: [
        Icon(AppIcons.search01, size: 20, color: _textSecondary),
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

  Widget _unsupportedComponent(EditableComponent component) {
    final entry = ComponentRegistry.get(component.componentType);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(AppIcons.layers01, size: 20, color: _accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry?.displayName ?? component.componentType,
                    style: TextStyle(
                      fontSize: AppFontSizes.size12 * _textFactor,
                      fontWeight: AppFontWeights.semiBold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'المعاينة المحلية لا ترسم هذا النوع بعد',
                    style: TextStyle(
                      fontSize: AppFontSizes.size10 * _textFactor,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerCarousel(EditableComponent c) {
    final height = (c.properties['height'] as num?)?.toDouble() ?? 184.0;
    final count = (_numProp(c, 'bannerDraftCount') ?? 0).round().clamp(0, 10);
    final bannerImages = c.properties['bannerDraftCount'] == null
        ? publishedBannerImages
        : [
            for (var index = 0; index < count; index++)
              c.properties['bannerDraft_${index}_image']?.toString() ?? '',
          ].where((url) => url.isNotEmpty).toList(growable: false);
    final hasDraftBanners = c.properties['bannerDraftCount'] != null;
    final radius = BorderRadius.circular(_radius(c.property('radius')));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: radius,
          child: bannerImages.isEmpty && !hasDraftBanners
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accent, _accent.withAlpha(120)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
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
                )
              : bannerImages.isEmpty
              ? Container(
                  color: _surface,
                  alignment: Alignment.center,
                  child: Icon(AppIcons.image01, color: _textSecondary),
                )
              : PageView.builder(
                  key: ValueKey(
                    'banner-preview-${c.componentId}-${bannerImages.join('|')}',
                  ),
                  itemCount: bannerImages.length,
                  itemBuilder: (context, index) => Image.network(
                    bannerImages[index],
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.fill,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: _surface,
                      child: Icon(AppIcons.image01, color: _textSecondary),
                    ),
                  ),
                ),
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
        _locOr(
          c,
          'title',
          _effectiveLanguage.isArabic ? 'التصنيفات' : 'Categories',
        ),
        show: c.properties['showTitle'] as bool? ?? true,
      ),
      SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: 8,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
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
        _locOr(
          c,
          'title',
          c.property('dataSource') == 'recommendations'
              ? (_effectiveLanguage.isArabic ? 'ترشيحات لك' : 'Recommendations')
              : (_effectiveLanguage.isArabic ? 'الأكثر طلبًا' : 'Popular'),
        ),
        show: true,
      ),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: (((c.properties['maxItems'] as num?) ?? 10).clamp(
            1,
            50,
          )).toInt(),
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
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
        _sectionTitle(_loc(c, 'title'), show: true),
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
          _locOr(
            c,
            'title',
            _effectiveLanguage.isArabic ? 'الباقات' : 'Bundles',
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
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
    final text = _loc(c, 'text');
    if (text.isEmpty) return const SizedBox.shrink();
    final size = _numProp(c, 'size') ?? 14.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(
        text,
        textAlign: switch (c.property('alignment')) {
          'center' => TextAlign.center,
          'end' => TextAlign.end,
          _ => TextAlign.start,
        },
        textDirection: switch (c.property('textDirection')) {
          'rtl' => TextDirection.rtl,
          'ltr' => TextDirection.ltr,
          _ => null,
        },
        style: TextStyle(
          fontSize: size * _textFactor,
          fontWeight: _weight(c.property('weight')),
          color: _hex(c.property('color')) ?? _textPrimary,
          height: (c.properties['lineHeight'] as num?)?.toDouble() ?? 1.4,
          letterSpacing: _numProp(c, 'letterSpacing'),
        ),
        maxLines: (c.properties['maxLines'] as num?)?.toInt(),
        overflow: switch (c.property('overflow')) {
          'clip' => TextOverflow.clip,
          'fade' => TextOverflow.fade,
          'visible' => TextOverflow.visible,
          _ => TextOverflow.ellipsis,
        },
      ),
    );
  }

  Widget _heading(EditableComponent c) {
    final title = _loc(c, 'title');
    final subtitle = _loc(c, 'subtitle');
    final linkLabel = _loc(c, 'linkLabel');
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

  Widget _button(EditableComponent c, {String fallbackLabel = ''}) {
    final label = _loc(c, 'label');
    final effectiveLabel = label.isEmpty ? fallbackLabel : label;
    if (effectiveLabel.isEmpty) return const SizedBox.shrink();
    final style = c.property('style') ?? 'primary';
    final savedBackground = _hex(c.property('color'));
    final bg = savedBackground?.toARGB32() == 0xFF2E7D32
        ? _accent
        : savedBackground ?? _accent;
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
                  effectiveLabel,
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
    final width = _numProp(c, 'width');
    final height = _numProp(c, 'height') ?? 160.0;
    final fit = switch (c.property('fit')) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'scaleDown' => BoxFit.scaleDown,
      _ => BoxFit.cover,
    };
    final alignment = switch (c.property('alignment')) {
      'start' => AlignmentDirectional.centerStart,
      'end' => AlignmentDirectional.centerEnd,
      _ => AlignmentDirectional.center,
    };
    Widget child;
    if (url.isEmpty) {
      child = Container(
        width: width,
        height: height,
        color: _surface,
        alignment: Alignment.center,
        child: Icon(AppIcons.image01, size: 28, color: _textSecondary),
      );
    } else {
      child = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: _surface,
          alignment: Alignment.center,
          child: Icon(AppIcons.image01, size: 28, color: _textSecondary),
        ),
      );
    }
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            _radius(c.property('borderRadius'), base: AppRadius.sm),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _divider(EditableComponent c) => Padding(
    padding: EdgeInsets.symmetric(horizontal: _spacing(c.property('inset'))),
    child: Divider(
      thickness: (c.properties['thickness'] as num?)?.toDouble() ?? 1,
      color: _hex(c.property('color')) ?? _borderColor,
    ),
  );

  Widget _spacer(EditableComponent c) {
    final height = _spacing(c.property('size'), fallback: AppSpacing.lg);
    final selected = c.componentId == selectedComponentId;
    return SizedBox(
      height: height,
      child: selected
          ? Container(
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: _accent.withAlpha(120), width: 1.5),
                color: _accent.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              alignment: Alignment.center,
              child: Text(
                'مسافة (${height.toInt()}px)',
                style: TextStyle(
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: AppFontWeights.medium,
                  color: _accent,
                ),
              ),
            )
          : null,
    );
  }

  /// رقم من خاصية قد تكون عددًا أو نصًّا (لوحة الخصائص ترسل النصّين).
  double? _numProp(EditableComponent c, String key) {
    final value = c.properties[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String _locOr(EditableComponent c, String base, String fallback) {
    final value = _loc(c, base);
    return value.isEmpty ? fallback : value;
  }

  /// نصّ ثنائي اللغة للمعاينة: لغة واجهة العميل أولًا، ثم الأخرى،
  /// ثم الاسم الأحادي القديم، كما يقرؤه تطبيق العميل.
  String _loc(EditableComponent c, String base) {
    String read(String key) => ((c.properties[key] as String?) ?? '').trim();
    final preferred = read(
      '${base}_${_effectiveLanguage.isArabic ? 'ar' : 'en'}',
    );
    if (preferred.isNotEmpty) return preferred;
    final other = read('${base}_${_effectiveLanguage.isArabic ? 'en' : 'ar'}');
    if (other.isNotEmpty) return other;
    return read(base);
  }

  // ------------------------------------------------------- الشاشات المدمجة

  Widget _splashSettings(EditableComponent c, BuildContext context) {
    final url = (c.properties['imageUrl'] as String?)?.trim() ?? '';
    final text = _loc(c, 'text');
    final size = _numProp(c, 'textSize') ?? 16;
    final previewSize = screenSize ?? MediaQuery.sizeOf(context);
    final shortestSide = previewSize.shortestSide;
    final imageWidth =
        (_numProp(c, 'imageWidth') ?? (shortestSide * 0.66).clamp(160.0, 320.0))
            .clamp(40.0, shortestSide)
            .toDouble();
    final imageShape = c.property('imageShape') ?? 'original';
    final configuredHeight = _numProp(c, 'imageHeight')?.clamp(40.0, 700.0);
    final imageHeight = imageShape == 'circle' || imageShape == 'square'
        ? imageWidth
        : configuredHeight;
    final imageCornerRadius = (_numProp(c, 'imageCornerRadius') ?? 16).clamp(
      0.0,
      200.0,
    );
    final imageGap = _numProp(c, 'imageGap') ?? AppSpacing.sm;
    final fit = switch (c.property('imageFit')) {
      'cover' => BoxFit.cover,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'scaleDown' => BoxFit.scaleDown,
      _ => BoxFit.contain,
    };
    final alignment = switch (c.property('imageAlignment')) {
      'topCenter' => Alignment.topCenter,
      'topLeft' => Alignment.topLeft,
      'topRight' => Alignment.topRight,
      'centerLeft' => Alignment.centerLeft,
      'centerRight' => Alignment.centerRight,
      'bottomLeft' => Alignment.bottomLeft,
      'bottomCenter' => Alignment.bottomCenter,
      'bottomRight' => Alignment.bottomRight,
      _ => Alignment.center,
    };
    final textAlignment = switch (c.property('textAlignment')) {
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.center,
    };
    final verticalAlignment = switch (c.property('verticalAlignment')) {
      'top' => MainAxisAlignment.start,
      'bottom' => MainAxisAlignment.end,
      _ => MainAxisAlignment.center,
    };
    final animation = c.property('animation') ?? 'fadeScale';
    final animationDuration =
        _numProp(c, 'animationDurationMs')?.round() ?? 300;
    final rawImage = url.isEmpty
        ? Image.asset(
            AppImages.logo,
            key: const ValueKey('splash-image-default'),
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            alignment: alignment,
            errorBuilder: (_, _, _) => Container(
              width: imageWidth,
              height: imageHeight,
              alignment: Alignment.center,
              color: _surface,
              child: Icon(AppIcons.image01, size: 30, color: _textSecondary),
            ),
          )
        : Image.network(
            url,
            key: ValueKey('splash-image-$url'),
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            alignment: alignment,
            errorBuilder: (_, _, _) => Container(
              width: imageWidth,
              height: imageHeight,
              color: _surface,
              alignment: Alignment.center,
              child: Icon(AppIcons.image01, color: _textSecondary),
            ),
          );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(switch (imageShape) {
        'circle' => imageWidth / 2,
        'rounded' => imageCornerRadius,
        _ => 0,
      }),
      child: SizedBox(width: imageWidth, height: imageHeight, child: rawImage),
    );
    final splashContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: verticalAlignment,
      children: [
        if (c.properties['imageVisible'] as bool? ?? true)
          Align(
            alignment: alignment,
            child: Padding(
              padding: EdgeInsets.all(_numProp(c, 'imagePadding') ?? 0),
              child: image,
            ),
          ),
        if (text.isNotEmpty) ...[
          SizedBox(
            height:
                (c.properties['imageVisible'] as bool? ?? true ? imageGap : 0) +
                (_numProp(c, 'textMarginTop') ?? 0),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _numProp(c, 'textPaddingHorizontal') ?? 0,
              _numProp(c, 'textPaddingVertical') ?? 0,
              _numProp(c, 'textPaddingHorizontal') ?? 0,
              (_numProp(c, 'textPaddingVertical') ?? 0) +
                  (_numProp(c, 'textMarginBottom') ?? 0),
            ),
            child: Text(
              text,
              textAlign: textAlignment,
              style: TextStyle(
                fontSize: size,
                color: _hex(c.property('textColor')) ?? _textPrimary,
                fontWeight: switch (c.property('textWeight')) {
                  'light' => FontWeight.w300,
                  'medium' => FontWeight.w500,
                  'bold' => FontWeight.bold,
                  _ => FontWeight.normal,
                },
              ),
            ),
          ),
        ],
      ],
    );
    final animatedContent = animation == 'none' || animationDuration <= 0
        ? splashContent
        : TweenAnimationBuilder<double>(
            key: ValueKey('$animation:$animationDuration'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: animationDuration.clamp(0, 5000)),
            curve: Curves.easeOutCubic,
            child: splashContent,
            builder: (context, progress, child) => Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: animation == 'fadeScale' ? 0.92 + 0.08 * progress : 1,
                child: child,
              ),
            ),
          );
    return Container(
      constraints: BoxConstraints(minHeight: previewSize.height),
      width: double.infinity,
      color: _hex(c.property('backgroundColor')) ?? Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: _numProp(c, 'contentPaddingHorizontal') ?? 24,
        vertical: _numProp(c, 'contentPaddingVertical') ?? 24,
      ),
      child: animatedContent,
    );
  }

  /// صورة الترحيب: الرابط المنشور أو الصورة المرفقة، بنفس مساحة الشاشة.
  Widget _welcomeHero(EditableComponent c) {
    final url = (c.properties['imageUrl'] as String?)?.trim() ?? '';
    final imageAlignment = switch (c.property('alignment')) {
      'topLeft' => Alignment.topLeft,
      'topRight' => Alignment.topRight,
      'centerLeft' => Alignment.centerLeft,
      'centerRight' => Alignment.centerRight,
      'bottomLeft' => Alignment.bottomLeft,
      'bottomCenter' => Alignment.bottomCenter,
      'bottomRight' => Alignment.bottomRight,
      'center' => Alignment.center,
      _ => Alignment.topCenter,
    };
    final imageFit = switch (c.property('fit')) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'scaleDown' => BoxFit.scaleDown,
      _ => BoxFit.cover,
    };
    Widget picture;
    if (url.isEmpty) {
      picture = Image.asset(
        AppImages.welcomeImage,
        fit: imageFit,
        alignment: imageAlignment,
        errorBuilder: (_, _, _) => ColoredBox(
          color: _surface,
          child: Center(
            child: Icon(AppIcons.image01, size: 32, color: _textSecondary),
          ),
        ),
      );
    } else {
      picture = Image.network(
        url,
        fit: imageFit,
        alignment: imageAlignment,
        errorBuilder: (_, _, _) => Container(
          color: _surface,
          alignment: Alignment.center,
          child: Icon(AppIcons.image01, size: 28, color: _textSecondary),
        ),
      );
    }
    final previewSize = screenSize ?? const Size(400, 700);
    final heightRatio = (_numProp(c, 'heightRatio') ?? 0.63).clamp(0.25, 0.85);
    return Opacity(
      opacity: (_numProp(c, 'opacity') ?? 1).clamp(0.0, 1.0),
      child: SizedBox(
        height: previewSize.height * heightRatio,
        width: double.infinity,
        child: SizedBox.expand(child: picture),
      ),
    );
  }

  /// عنوان الترحيب: جزؤه الملوّن وباقيه، أو نصّ الشاشة حين يُترك فارغًا.
  Widget _welcomeTitle(EditableComponent c) {
    final highlight = _loc(c, 'highlight');
    final rest = _loc(c, 'rest');
    final size = _numProp(c, 'size') ?? 24.0;
    final alignment = switch (c.property('alignment')) {
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.center,
    };
    final weight = switch (c.property('textWeight')) {
      'light' => FontWeight.w300,
      'regular' => FontWeight.normal,
      'medium' => FontWeight.w500,
      'semibold' => FontWeight.w600,
      'bold' => FontWeight.bold,
      _ => FontWeight.w600,
    };
    if (highlight.isEmpty && rest.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(
          'قهوتك… لحظتك',
          textAlign: alignment,
          style: TextStyle(
            fontSize: size * _textFactor,
            fontWeight: AppFontWeights.bold,
            color: _textSecondary,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text.rich(
        textAlign: alignment,
        TextSpan(
          children: [
            if (highlight.isNotEmpty)
              TextSpan(
                text: highlight,
                style: TextStyle(
                  fontSize: size * _textFactor,
                  fontWeight: weight,
                  color: _hexColor(c.property('highlightColor')) ?? _accent,
                ),
              ),
            if (highlight.isNotEmpty && rest.isNotEmpty)
              const TextSpan(text: ' '),
            if (rest.isNotEmpty)
              TextSpan(
                text: rest,
                style: TextStyle(
                  fontSize: size * _textFactor,
                  fontWeight: weight,
                  color: _hexColor(c.property('restColor')) ?? _textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// مسافات لوحة الترحيب: بين الموجة والنصّ، وبين العنوان ووصفه.
  Widget _welcomeCta(EditableComponent c) {
    final label = _loc(c, 'label').trim();
    final radius = (_numProp(c, 'borderRadius') ?? 16).clamp(0.0, 60.0);
    final height = (_numProp(c, 'height') ?? 52).clamp(32.0, 100.0);
    final outlined = c.property('style') == 'outlined';
    final background = _hexColor(c.property('backgroundColor')) ?? _accent;
    final foreground = _hexColor(c.property('textColor')) ?? Colors.white;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : background,
          borderRadius: BorderRadius.circular(radius),
          border: outlined ? Border.all(color: background) : null,
        ),
        child: Center(
          child: Text(
            label.isEmpty
                ? (_effectiveLanguage == PreviewLanguage.arabic
                      ? 'لنبدأ'
                      : "Let's Get Started")
                : label,
            style: TextStyle(
              color: outlined ? background : foreground,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeSpacing(EditableComponent c) {
    return SizedBox(height: _numProp(c, 'gap') ?? AppSpacing.md);
  }

  Widget _onboardingSlide(EditableComponent c) {
    final url = (c.properties['imageUrl'] as String?)?.trim() ?? '';
    final title = _loc(c, 'title');
    final body = _loc(c, 'body');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radius('lg')),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_radius('md')),
            child: SizedBox(
              height: 120,
              child: url.isEmpty
                  ? Container(
                      color: _bg,
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.image01,
                        size: 24,
                        color: _textSecondary,
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.fill,
                      errorBuilder: (_, _, _) => Container(
                        color: _bg,
                        alignment: Alignment.center,
                        child: Icon(
                          AppIcons.image01,
                          size: 24,
                          color: _textSecondary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title.isEmpty ? 'عنوان الشريحة (من المصدر)' : title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSizes.size16 * _textFactor,
              fontWeight: AppFontWeights.bold,
              color: title.isEmpty ? _textSecondary : _textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            body.isEmpty ? 'وصف الشريحة (من المصدر)' : body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSizes.size12 * _textFactor,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// وقت الانتقال: مدة الحركة والتقديم التلقائي كما نشرهما الموظف.
  Widget _onboardingTransition(EditableComponent c) {
    final duration = _numProp(c, 'durationMs');
    final seconds = _numProp(c, 'seconds');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(
        'الانتقال: ${duration == null ? 'حركة الشاشة' : '${duration.round()}ms'}'
        ' • ${seconds != null && seconds >= 1 ? 'تلقائي كل ${seconds.round()}ث' : 'يدوي'}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppFontSizes.size10 * _textFactor,
          color: _textSecondary,
        ),
      ),
    );
  }

  Widget _authSocial() => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(_radius('pill')),
                border: Border.all(color: _borderColor),
              ),
              child: Text(
                i == 0 ? 'Google' : 'متابعة',
                style: TextStyle(
                  fontSize: AppFontSizes.size12 * _textFactor,
                  color: _textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _authSwitchPrompt() => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Text(
      'ليس لديك حساب؟ إنشاء حساب',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: AppFontSizes.size12 * _textFactor,
        color: _textSecondary,
      ),
    ),
  );

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
      padding: EdgeInsets.symmetric(horizontal: _spacing(c.property('inset'))),
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

  Widget _row(
    EditableComponent c,
    Map<String, List<EditableComponent>> byParent,
  ) {
    final children = byParent[c.componentId] ?? const [];
    final rendered = <Widget>[];
    for (final child in children) {
      final widget = _render(child, byParent);
      if (widget == null) continue;
      if (rendered.isNotEmpty) {
        rendered.add(SizedBox(width: _spacing(c.property('gap'))));
      }
      rendered.add(Expanded(child: widget));
    }
    if (rendered.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _spacing(c.property('inset'))),
      child: Row(
        crossAxisAlignment: switch (c.property('crossAxisAlignment')) {
          'start' => CrossAxisAlignment.start,
          'end' => CrossAxisAlignment.end,
          'stretch' => CrossAxisAlignment.stretch,
          _ => CrossAxisAlignment.center,
        },
        children: rendered,
      ),
    );
  }

  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final trimmed = hex.trim();
    final value = int.tryParse(trimmed.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return trimmed.replaceFirst('#', '').length == 8
        ? Color(value)
        : Color(0xFF000000 | value);
  }

  /// يطبق خصائص Chrome (التخطيط والمظهر) على عنصر، مطابقًا لـ DesignSectionChrome.
  Widget _applyChrome(EditableComponent c, Widget child) {
    Widget current = child;
    final needsChrome = _needsChrome(c);
    if (!needsChrome) return current;

    // Opacity first
    final opacity = _numProp(c, 'opacity');
    if (opacity != null && opacity >= 0 && opacity <= 1) {
      current = Opacity(opacity: opacity, child: current);
    }

    // Aspect ratio
    final aspectRatio = _numProp(c, 'aspectRatio');
    if (aspectRatio != null && aspectRatio > 0) {
      current = AspectRatio(aspectRatio: aspectRatio, child: current);
    }

    // Padding
    final padLeft = _numProp(c, 'padLeft');
    final padRight = _numProp(c, 'padRight');
    final padTop = _numProp(c, 'padTop');
    final padBottom = _numProp(c, 'padBottom');
    if (padLeft != null ||
        padRight != null ||
        padTop != null ||
        padBottom != null) {
      current = Padding(
        padding: EdgeInsets.only(
          left: padLeft ?? 0,
          right: padRight ?? 0,
          top: padTop ?? 0,
          bottom: padBottom ?? 0,
        ),
        child: current,
      );
    }

    // Background, border, radius, shadow
    final background = _hexColor(c.property('backgroundColor'));
    final borderColor = _hexColor(c.property('borderColor'));
    final borderWidth = _numProp(c, 'borderWidth');
    final hasRadius =
        c.properties.containsKey('radiusTL') ||
        c.properties.containsKey('radiusTR') ||
        c.properties.containsKey('radiusBL') ||
        c.properties.containsKey('radiusBR');
    final hasShadow = c.properties.containsKey('shadowColor');
    if (background != null || borderColor != null || hasRadius || hasShadow) {
      final tl = _numProp(c, 'radiusTL') ?? 0;
      final tr = _numProp(c, 'radiusTR') ?? 0;
      final bl = _numProp(c, 'radiusBL') ?? 0;
      final br = _numProp(c, 'radiusBR') ?? 0;
      final radius = BorderRadius.only(
        topLeft: Radius.circular(tl),
        topRight: Radius.circular(tr),
        bottomLeft: Radius.circular(bl),
        bottomRight: Radius.circular(br),
      );
      final shadowColor = _hexColor(c.property('shadowColor'));
      final decoration = BoxDecoration(
        color: background,
        borderRadius: radius,
        border: (borderColor != null || borderWidth != null)
            ? Border.all(
                color: borderColor ?? const Color(0xFF000000),
                width: borderWidth ?? 1,
              )
            : null,
        boxShadow: shadowColor == null
            ? null
            : [
                BoxShadow(
                  color: shadowColor,
                  offset: Offset(
                    _numProp(c, 'shadowOffsetX') ?? 0,
                    _numProp(c, 'shadowOffsetY') ?? 2,
                  ),
                  blurRadius: _numProp(c, 'shadowBlur') ?? 8,
                ),
              ],
      );
      current = DecoratedBox(decoration: decoration, child: current);
      if (hasRadius || borderColor != null || borderWidth != null) {
        current = ClipRRect(borderRadius: radius, child: current);
      }
    }

    // Width/height constraints (structural height components handle height differently)
    final structuralHeight =
        c.componentType == 'bannerCarousel' || c.componentType == 'promoBanner';
    final width = _numProp(c, 'width');
    final height = structuralHeight ? null : _numProp(c, 'height');
    final minWidth = _numProp(c, 'minWidth');
    final maxWidth = _numProp(c, 'maxWidth');
    final minHeight = _numProp(c, 'minHeight');
    final maxHeight = _numProp(c, 'maxHeight');
    if (width != null ||
        height != null ||
        minWidth != null ||
        maxWidth != null ||
        minHeight != null ||
        maxHeight != null) {
      current = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          maxWidth: maxWidth ?? double.infinity,
          minHeight: minHeight ?? 0,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: SizedBox(width: width, height: height, child: current),
      );
    }

    // Margin (applied last, outside everything)
    final mLeft = _numProp(c, 'marginLeft');
    final mRight = _numProp(c, 'marginRight');
    final mTop = _numProp(c, 'marginTop');
    final mBottom = _numProp(c, 'marginBottom');
    if (mLeft != null || mRight != null || mTop != null || mBottom != null) {
      current = Padding(
        padding: EdgeInsets.only(
          left: mLeft ?? 0,
          right: mRight ?? 0,
          top: mTop ?? 0,
          bottom: mBottom ?? 0,
        ),
        child: current,
      );
    }
    return current;
  }

  bool _needsChrome(EditableComponent c) {
    const keys = [
      'width',
      'minWidth',
      'maxWidth',
      'height',
      'minHeight',
      'maxHeight',
      'padTop',
      'padBottom',
      'padLeft',
      'padRight',
      'marginTop',
      'marginBottom',
      'marginLeft',
      'marginRight',
      'backgroundColor',
      'borderColor',
      'borderWidth',
      'radiusTL',
      'radiusTR',
      'radiusBL',
      'radiusBR',
      'shadowColor',
      'shadowOffsetX',
      'shadowOffsetY',
      'shadowBlur',
      'opacity',
      'aspectRatio',
    ];
    for (final key in keys) {
      final value = c.properties[key];
      if (value is num || (value is String && value.trim().isNotEmpty)) {
        return true;
      }
    }
    return false;
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
    final clean = hex.trim().replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    // `#AARRGGBB` يحمل alpha؛ `#RRGGBB` يكمل بـ FF. الطول هنا بعد إزالة `#`.
    return clean.length == 8 ? Color(value) : Color(0xFF000000 | value);
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

class _WelcomePanelClipper extends CustomClipper<Path> {
  const _WelcomePanelClipper(this.depth);

  final double depth;

  @override
  Path getClip(Size size) {
    final scale = depth / 55;
    return Path()
      ..moveTo(0, depth)
      ..cubicTo(size.width * .18, depth, size.width * .22, 0, size.width * .48, 0)
      ..cubicTo(size.width * .72, 0, size.width * .78, 34 * scale, size.width, 24 * scale)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WelcomePanelClipper oldClipper) =>
      oldClipper.depth != depth;
}
