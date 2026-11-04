import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/domain/registry/action_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/design_tokens.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_banner_carousel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_bundle_strip.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_marquee.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_tabs.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_empty_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_home_header.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_no_banner_note.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_card.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_grid.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_strip.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_promo_banner.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_search_field.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_section_heading.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

/// يلفّ عقدة الرسم في اللوحة: حدود التحديد ومؤشر الإفلات هناك، لا هنا.
typedef DesignNodeDecorator = Widget Function(
  BuildContext context,
  DesignNode node,
  Widget child,
);

/// موضع إفلات بين مقاطع الصفحة: `[index]` موضع في قائمة أبناء الأب نفسها، وهو ما
/// تحسبه مؤشرات اللوحة، فيبقى ما يراه الموظف هو ما يُفلت.
typedef DesignSectionSlotBuilder = Widget Function(
  BuildContext context,
  DesignNode parent,
  int index,
);

/// ما تحتاجه صفحة مبنية من مستند: بيانات الزبون الحقيقية، ولغته، وضغطاته.
///
/// لا قراءة هنا ولا تحويل: [feed] هو [CustomerFeed] نفسه الذي تبنيه قراءة
/// صفحات الإدارة، فالأسعار والنافذة النشرية والترشيحات الموسمية قاعدة واحدة
/// يمشي عليها المحاكي اليدوي وهذا الرسم.
class DesignRenderScope {
  const DesignRenderScope({
    required this.feed,
    required this.language,
    required this.labels,
    required this.now,
    this.query = '',
    this.categoryId,
    this.onSearchChanged,
    this.onSelectCategory,
    this.onNavigate,
    this.onOpenProduct,
    this.onSeeAll,
  });

  final CustomerFeed feed;
  final AppLanguage language;
  final SimulatorLabels labels;

  /// وقت واحد للتحية وشريط الحالة، كما تُقرأ مرة واحدة في الجوف.
  final DateTime now;

  final String query;

  /// التصنيف الذي يقف عليه الهاتف، وهو ما يغذّي مصادر «منتجات تصنيف» بلا
  /// خاصية على كل مقطع.
  final String? categoryId;

  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSelectCategory;
  final ValueChanged<AppPage>? onNavigate;
  final ValueChanged<PreviewProduct>? onOpenProduct;

  /// «عرض المزيد» على مصدر المقطع نفسه، والعقدة تحمل عنوانه ومصدره.
  final ValueChanged<DesignNode>? onSeeAll;

  /// صفوف مصدر العقدة، من نفس ما قرأته اللوحة. بلا مصدر أو بصفوف لا توجد
  /// ترجع قائمة فارغة، والمقطع الذي لا صفوف له يختفي كما عند الزبون.
  List<PreviewProduct> productsOf(DesignNode node) => _cap(_rowsOf(node), node);

  /// كل صفوف المصدر بلا سقف المقطع: صفحة «عرض المزيد» تُري البقية، والشريط
  /// يكتفي بعشر بطاقات كما عند الزبون.
  List<PreviewProduct> allProductsOf(DesignNode node) => _rowsOf(node);

  List<PreviewProduct> _rowsOf(DesignNode node) =>
      switch (node.stringProperty('dataSource')) {
        DataSourceRegistry.featured => feed.featured,
        DataSourceRegistry.recommendations => feed.recommendations(),
        DataSourceRegistry.categoryProducts => _categoryProducts(node),
        DataSourceRegistry.searchResults => feed.search(query),
        _ => feed.catalog,
      };

  List<AdminBanner> bannersOf(DesignNode node) =>
      _cap(feed.publishedBanners, node);

  /// بانر واحد من النافذة برقمه المحفوظ في العقدة، والثاني هو ما يعرضه العميل.
  AdminBanner? promoOf(DesignNode node) {
    final index = node.intProperty('bannerIndex', fallback: 1) - 1;
    final banners = feed.publishedBanners;
    if (index < 0 || index >= banners.length) return null;
    return banners[index];
  }

  List<AdminCategory> categoriesOf(DesignNode node) =>
      _cap(feed.visibleCategories, node);

  List<AdminBundle> bundlesOf(DesignNode node) =>
      _cap(feed.visibleBundles, node);

  PreviewProduct? productById(String id) {
    if (id.isEmpty) return null;
    for (final product in feed.catalog) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// اسم مصدر العقدة بلغة الهاتف، لعنوان صفحة «عرض المزيد» حين لا عنوان لها.
  String sourceNameOf(DesignNode node) =>
      DataSourceRegistry.of(node.stringProperty('dataSource'))?.name
          .of(language) ??
      '';

  /// السطر الموسمي لمصدر الترشيحات وحده، وهي قاعدة العميل: يطبعه حين تنجح
  /// قراءة الطقس وحين تكون البركة قد وصلت.
  String? seasonalOf(DesignNode node) {
    if (node.stringProperty('dataSource') !=
        DataSourceRegistry.recommendations) {
      return null;
    }
    if (!feed.hasWeather || feed.recommendationPool.isEmpty) return null;
    return feed.isHotDay ? labels.hotDayPicks : labels.coldDayPicks;
  }

  /// تنفيذ إجراء مسجَّل. ما لا شاشة له في اللوحة لا يُنفَّذ ولا يُوهم بأنه يعمل.
  void run(String actionKey, DesignNode node) {
    switch (actionKey) {
      case ActionRegistry.navigateHome:
        onNavigate?.call(AppPage.home);
      case ActionRegistry.navigateCategories:
        onNavigate?.call(AppPage.categories);
      case ActionRegistry.navigateSearch:
        onNavigate?.call(AppPage.search);
      case ActionRegistry.navigateCart:
        onNavigate?.call(AppPage.cart);
      case ActionRegistry.navigateFavourites:
        onNavigate?.call(AppPage.favourites);
      case ActionRegistry.navigateSettings:
        onNavigate?.call(AppPage.settings);
      case ActionRegistry.openCategory:
        final id = node.stringProperty('categoryId');
        if (id.isEmpty) {
          onNavigate?.call(AppPage.categories);
        } else {
          onSelectCategory?.call(id);
        }
      case ActionRegistry.openProduct:
        final product = productById(node.stringProperty('productId'));
        if (product != null) onOpenProduct?.call(product);
      case ActionRegistry.seeAllProducts:
        onSeeAll?.call(node);
      case ActionRegistry.none:
        break;
    }
  }

  List<PreviewProduct> _categoryProducts(DesignNode node) {
    final id = node.stringProperty('categoryId');
    final current = id.isEmpty ? categoryId : id;
    if (current == null) return const <PreviewProduct>[];
    return feed.productsInCategory(current);
  }

  /// سقف المقطع: خاصية maxItems إن كان المكوّن يعرفها، وكل الصفوف إن لم يعرفها.
  /// لا سقف ضمني هنا — شبكة بلا maxItems تعرض ما وصل اللوحة كله.
  List<T> _cap<T>(List<T> rows, DesignNode node) {
    if (WidgetRegistry.of(node.type)?.property('maxItems') == null) return rows;
    final limit = node.intProperty('maxItems', fallback: CustomerFeed.stripCap);
    if (limit <= 0) return List<T>.empty();
    return rows.length > limit ? rows.sublist(0, limit) : rows;
  }
}

/// يرسم شجرة صفحة من مستند التصميم بأدويتها الحقيقية.
///
/// كل نوع مسجَّل له رسم هنا، ولا نوع هنا بلا شاشة تنفّذه: المقطع الذي لا بيانات
/// له يختفي كما يختفي عند الزبون. العقدة المخفية لا تُرسم لما يراه الزبون، أما
/// في اللوحة فتُمرّ إلى [decorate] حتى تُرى ويُعاد إظهارها منها.
class DesignRenderer extends StatelessWidget {
  const DesignRenderer({
    super.key,
    required this.node,
    required this.scope,
    this.decorate,
    this.sectionSlot,
  });

  final DesignNode node;
  final DesignRenderScope scope;

  /// يلفّ كل عقدة برسمها: used في اللوحة للتحديد والإفلات، وتُترك null لما يراه
  /// الزبون.
  final DesignNodeDecorator? decorate;

  /// مواضع الإفلات بين مقاطع الصفحة، تُرسم في اللوحة وحدها: الرسم يعرف ترتيب
  /// الأبناء كما في المستند، فلا تُحسب المؤشرات من قائمة ثانية قد تتباعد عنه.
  final DesignSectionSlotBuilder? sectionSlot;

  @override
  Widget build(BuildContext context) {
    if (!WidgetRegistry.knows(node.type)) return const SizedBox.shrink();
    final content = _content(context);
    final decorator = decorate;
    if (decorator != null) return decorator(context, node, content);
    // العقدة التي أخفاها المحرّر لا تصل إلى شاشة الزبون، وهي تبقى في المستند.
    return node.isVisible ? content : const SizedBox.shrink();
  }

  /// أبناء العقدة كما تُرسم: في اللوحة كل الأبناء، وفي المشاهدة الظاهرون فقط.
  List<DesignNode> get children => decorate == null
      ? node.children.where((child) => child.isVisible).toList(growable: false)
      : node.children;

  Widget _content(BuildContext context) {
    switch (node.type) {
      case WidgetTypes.pageHome:
      case WidgetTypes.pageCategories:
      case WidgetTypes.pageSearch:
        return _page(context);
      case WidgetTypes.header:
        return SimulatorHomeHeader(labels: scope.labels, now: scope.now);
      case WidgetTypes.searchBar:
        return SimulatorSearchField(
          value: scope.query,
          hintText: node.stringProperty('hint').isEmpty
              ? scope.labels.searchHint
              : node.stringProperty('hint'),
          onChanged: scope.onSearchChanged ?? (_) {},
        );
      case WidgetTypes.bannerCarousel:
        return _banners(context);
      case WidgetTypes.promoBanner:
        return _promo();
      case WidgetTypes.categoryList:
        return _categoryList(context);
      case WidgetTypes.productStrip:
        return _strip(context);
      case WidgetTypes.productGrid:
        return _gridBox(context);
      case WidgetTypes.bundleList:
        return _bundles(context);
      case WidgetTypes.heading:
        return _headingOf(context, node);
      case WidgetTypes.text:
        return _paragraph(context);
      case WidgetTypes.divider:
        return _divider(context);
      case WidgetTypes.spacer:
        return SizedBox(
          height: DesignTokens.spacing(
            node.stringProperty('size', fallback: 'lg'),
          ),
        );
      case WidgetTypes.column:
        return _column(context);
      case WidgetTypes.button:
        return _button(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------- الصفحة ----------

  /// صفحة بمقاطعها، بتمرير واحد: شبكة المنتجات sliver لا تمرير داخل تمرير،
  /// فتبقى البطاقات تُبنى نزولًا كما عند الزبون.
  Widget _page(BuildContext context) {
    final rows = children;
    final slivers = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
    ];
    for (var index = 0; index < rows.length; index++) {
      if (index > 0) {
        slivers.add(
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        );
      }
      _addSlot(context, slivers, index);
      slivers.addAll(_slivers(context, rows[index]));
    }
    _addSlot(context, slivers, rows.length);
    slivers.add(
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
    );
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }

  /// موضع إفلات واحد قبل الابن `[index]`، ولا شيء منه فيما يراه الزبون.
  void _addSlot(BuildContext context, List<Widget> slivers, int index) {
    final slot = sectionSlot;
    if (slot == null) return;
    slivers.add(SliverToBoxAdapter(child: slot(context, node, index)));
  }

  /// الشبكة sliver داخل تمرير الصفحة، فتُبنى بطاقاتها نزولًا كما عند الزبون؛
  /// وما عداها صندوق واحد بحافّته.
  List<Widget> _slivers(BuildContext context, DesignNode child) {
    if (child.type != WidgetTypes.productGrid || decorate != null) {
      return <Widget>[
        SliverToBoxAdapter(child: _edge(child, _draw(context, child))),
      ];
    }
    final products = scope.productsOf(child);
    final heading = _gridHeading(context, child, products);
    if (products.isEmpty) {
      return <Widget>[
        if (heading != null) SliverToBoxAdapter(child: _edge(child, heading)),
        SliverToBoxAdapter(child: _edge(child, _gridEmpty())),
      ];
    }
    return <Widget>[
      if (heading != null) SliverToBoxAdapter(child: _edge(child, heading)),
      SliverPadding(
        padding: SimulatorProductGrid.gridPadding,
        sliver: SliverGrid(
          gridDelegate: SimulatorProductGrid.gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) => SimulatorProductCard(
              product: products[index],
              language: scope.language,
              showPrice: child.boolProperty('showPrice', fallback: true),
            ),
            childCount: products.length,
          ),
        ),
      ),
    ];
  }

  /// حافة المقطع الجانبية. ما يملك حافّته في رسمه نفسه — البنر كامل العرض،
  /// والشبكة بترقيمها، والعمود بـ inset، والفاصل بـ indent — لا تُضاعَف له
  /// حافة الصفحة، وإلا بَصمت المسافات مزدوجة أمام الموظف.
  Widget _edge(DesignNode child, Widget content) {
    if (_selfEdged.contains(child.type)) return content;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: content,
    );
  }

  static const Set<String> _selfEdged = <String>{
    WidgetTypes.bannerCarousel,
    WidgetTypes.productGrid,
    WidgetTypes.column,
    WidgetTypes.divider,
  };

  Widget _draw(BuildContext context, DesignNode child) =>
      DesignRenderer(node: child, scope: scope, decorate: decorate);

  // ---------- المقاطع ----------

  Widget _banners(BuildContext context) {
    final banners = scope.bannersOf(node);
    if (banners.isEmpty) {
      // الخفاء قرار في التوقيت لا خلل في القراءة، والسطر ملاحظة للموظف كما في
      // شاشة الرئيسية المبنية يدويًا.
      return SimulatorNoBannerNote(label: scope.labels.noBanners);
    }
    return SimulatorBannerCarousel(
      banners: banners,
      autoplay: node.boolProperty('autoplay', fallback: true),
      radius: DesignTokens.radius(
        node.stringProperty('radius', fallback: 'none'),
      ),
    );
  }

  Widget _promo() {
    final banner = scope.promoOf(node);
    if (banner == null) return const SizedBox.shrink();
    return SimulatorPromoBanner(
      banner: banner,
      radius: DesignTokens.radius(
        node.stringProperty('radius', fallback: 'md'),
      ),
    );
  }

  Widget _categoryList(BuildContext context) {
    final categories = scope.categoriesOf(node);
    if (categories.isEmpty) return const SizedBox.shrink();
    final marquee =
        node.stringProperty('layout', fallback: 'marquee') != 'tabs';
    final body = marquee
        ? SimulatorCategoryMarquee(
            categories: categories,
            language: scope.language,
            onSelect: (category) => scope.onSelectCategory?.call(category.id),
          )
        : SimulatorCategoryTabs(
            categories: categories,
            selectedId: scope.categoryId,
            language: scope.language,
            onSelect: (category) => scope.onSelectCategory?.call(category.id),
          );
    return _titled(context, title: node.stringProperty('title'), body: body);
  }

  Widget _strip(BuildContext context) {
    final products = scope.productsOf(node);
    if (products.isEmpty) return const SizedBox.shrink();
    return _titled(
      context,
      title: node.stringProperty('title'),
      subtitle: scope.seasonalOf(node),
      body: SimulatorProductStrip(
        products: products,
        language: scope.language,
        showPrice: node.boolProperty('showPrice', fallback: true),
      ),
    );
  }

  Widget _bundles(BuildContext context) {
    final bundles = scope.bundlesOf(node);
    if (bundles.isEmpty) return const SizedBox.shrink();
    final strip = node.stringProperty('layout', fallback: 'strip') != 'list';
    final body = strip
        ? SimulatorBundleStrip(
            bundles: bundles,
            feed: scope.feed,
            language: scope.language,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final bundle in bundles)
                SimulatorBundleListTile(
                  bundle: bundle,
                  original: scope.feed.bundleOriginalTotal(bundle),
                  language: scope.language,
                ),
            ],
          );
    return _titled(context, title: node.stringProperty('title'), body: body);
  }

  /// عنوان المقطع فوق محتواه، بلا عنوان حين لا تسمية: كما يخفي العميل رأسه
  /// حين لا صفوف تحته، يُخفي الموظف رأسه حين لا يريد واحدًا.
  Widget _titled(
    BuildContext context, {
    required String title,
    required Widget body,
    String? subtitle,
  }) {
    if (title.trim().isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headingOf(context, node, title: title, subtitle: subtitle),
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }

  /// عنوان الشبكة: ما يسمّيه الموظف، وعدد النتائج مكانه حين تكون الشبكة نتائج
  /// بحث بلا تسمية — وهو ما يطبعه المحاكي اليدوي، لا رقمًا يُختَرع هنا.
  Widget? _gridHeading(
    BuildContext context,
    DesignNode target,
    List<PreviewProduct> products,
  ) {
    var title = target.stringProperty('title');
    if (title.trim().isEmpty &&
        target.stringProperty('dataSource') ==
            DataSourceRegistry.searchResults) {
      title = scope.labels.searchResults(products.length);
    }
    if (title.trim().isEmpty) return null;
    return _headingOf(context, target, title: title);
  }

  /// الشبكة داخل عمود أو أمام اللوحة: تمريرها مطفأ لأنها تأخذ قدر صفوفها،
  /// والصفحة حولها هي التي تتمّر.
  Widget _gridBox(BuildContext context) {
    final products = scope.productsOf(node);
    final heading = _gridHeading(context, node, products);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null) ...[
          heading,
          const SizedBox(height: AppSpacing.md),
        ],
        if (products.isEmpty)
          _gridEmpty()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: SimulatorProductGrid.gridPadding,
            gridDelegate: SimulatorProductGrid.gridDelegate,
            itemCount: products.length,
            itemBuilder: (context, index) => SimulatorProductCard(
              product: products[index],
              language: scope.language,
              showPrice: node.boolProperty('showPrice', fallback: true),
            ),
          ),
      ],
    );
  }

  Widget _gridEmpty() => SimulatorEmptyState(
    icon: AppIcons.coffee01,
    title: scope.labels.noProducts,
  );

  // ---------- المحتوى والتخطيط ----------

  Widget _headingOf(
    BuildContext context,
    DesignNode target, {
    String? title,
    String? subtitle,
  }) {
    final link = target.stringProperty('linkLabel');
    final action = target.stringProperty('action');
    return SimulatorSectionHeading(
      title: title ?? target.stringProperty('title'),
      subtitle: subtitle ?? target.stringProperty('subtitle'),
      titleStyle: DesignTokens.text(
        context,
        target.stringProperty('titleSize', fallback: '16'),
        strong: true,
      ),
      trailingLabel: link.isEmpty ? null : link,
      onTapTrailing: link.isEmpty || action == ActionRegistry.none
          ? null
          : () => scope.run(action, target),
    );
  }

  Widget _paragraph(BuildContext context) {
    final palette = SimulatorPalette.of(context);
    final align = node.stringProperty('align', fallback: 'start') == 'center'
        ? TextAlign.center
        : TextAlign.start;
    return Text(
      node.stringProperty('text'),
      textAlign: align,
      style: DesignTokens.text(
        context,
        node.stringProperty('size', fallback: '14'),
      ).copyWith(
        color: palette.textPrimary ?? adminHeadingColor(Theme.of(context)),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final palette = SimulatorPalette.of(context);
    final inset = DesignTokens.spacing(
      node.stringProperty('inset', fallback: 'lg'),
    );
    return Divider(
      thickness: AppSizes.px1,
      indent: inset,
      endIndent: inset,
      color: palette.border ?? adminCardBorderColor(Theme.of(context)),
    );
  }

  Widget _column(BuildContext context) {
    final gap = DesignTokens.spacing(
      node.stringProperty('gap', fallback: 'lg'),
    );
    final inset = DesignTokens.spacing(
      node.stringProperty('inset', fallback: 'lg'),
    );
    final rows = children;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) SizedBox(height: gap),
            _draw(context, rows[index]),
          ],
        ],
      ),
    );
  }

  Widget _button(BuildContext context) {
    final action = node.stringProperty('action', fallback: ActionRegistry.none);
    return CustomBtn(
      text: node.stringProperty('label'),
      // زرّ بلا إجراء مسجَّل لا يُوهم بالضغط: يبقى معتمًا كما يراه الزبون عاجزًا.
      onPressed: action == ActionRegistry.none
          ? null
          : () => scope.run(action, node),
      variant: node.stringProperty('style', fallback: 'primary') == 'outline'
          ? BtnVariant.outlined
          : BtnVariant.primary,
    );
  }
}
