import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_banner_carousel.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_bundle_strip.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_marquee.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_empty_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_home_header.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_grid.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_strip.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_promo_banner.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_search_field.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_section_heading.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_no_banner_note.dart';

/// صفحة العميل الرئيسية كما يبنيها ترتيب المقاطع هناك، وبأرقام ذلك الترتيب.
///
/// المقاطع تختفي حين لا صفوف لها — كما يختفي `HomeBannerSection` وزملاؤه — فلا
/// عنوان فوق فراغ. استثناء واحد: مقطع البنر يعرض سطرًا للموظف يشرح أن الخفاء
/// قرار في التوقيت لا خلل في القراءة، لأنه المقطع الوحيد الذي يخفى لسبب لا يظهر
/// في القاعدة.
///
/// للوحة حالتان فوق المقاطع: الكتابة في البحث تُبدل body الصفحة بنتائجها،
/// و«عرض المزيد» تفتح صفحة كل صفوف الشريط. السبب أن البحث عند العميل صفحة لا
/// مقطعًا، وأن الشريط يكتفي بعشر بطاقات والبقية تُشاهَد في تلك الصفحة.
class SimulatorHomeScreen extends StatefulWidget {
  const SimulatorHomeScreen({
    super.key,
    required this.feed,
    required this.language,
    required this.labels,
    required this.query,
    required this.now,
    required this.onSearchChanged,
    required this.onSelectCategory,
    required this.onSeeAllCategories,
    this.onRefresh,
  });

  final CustomerFeed feed;
  final AppLanguage language;
  final SimulatorLabels labels;
  final String query;

  /// وقت واحد للتحية ولشريط الحالة: لقراءتين متفرقتين قد تُبدّل التحية ساعتها
  /// تحت عين الموظف.
  final DateTime now;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onSeeAllCategories;

  /// إعادة القراءة بالسحب داخل الهاتف، كما يفعل `HomePageBody` عند العميل.
  /// بلاها لا يُلفّ الهاتف في طبقة سحب.
  final Future<void> Function()? onRefresh;

  @override
  State<SimulatorHomeScreen> createState() => _SimulatorHomeScreenState();
}

/// الشريط الذي فُتح «عرض المزيد» عنه.
enum _Strip { popular, recommendations }

class _SimulatorHomeScreenState extends State<SimulatorHomeScreen> {
  _Strip? _opened;

  @override
  Widget build(BuildContext context) {
    final onRefresh = widget.onRefresh;
    final page = _page(context);
    if (onRefresh == null) return page;
    return RefreshIndicator(onRefresh: onRefresh, child: page);
  }

  Widget _page(BuildContext context) {
    final query = widget.query.trim();
    if (query.isNotEmpty) {
      final products = widget.feed.search(query);
      return _filteredPage(
        title: widget.labels.searchResults(products.length),
        products: products,
        // حقل الكتابة يبقى فوق نتائجه كما يبقى عند العميل: إخفاؤه مع أول حرف
        // يترك الموظف محبوسًا في كلمة لا سبيل إلى مسحها من داخل الهاتف.
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: SimulatorSearchField(
            value: widget.query,
            hintText: widget.labels.searchHint,
            onChanged: widget.onSearchChanged,
          ),
        ),
        empty: SimulatorEmptyState(
          icon: AppIcons.search01,
          title: widget.labels.noProducts,
          subtitle: query,
        ),
      );
    }
    final opened = _opened;
    if (opened != null) {
      final popular = opened == _Strip.popular;
      final products = popular
          ? widget.feed.featured
          : widget.feed.recommendations();
      return _filteredPage(
        title: popular ? widget.labels.popular : widget.labels.recommendations,
        subtitle: popular ? null : _seasonalLabel(),
        products: products,
        trailingLabel: widget.labels.back,
        onTapTrailing: () => setState(() => _opened = null),
        empty: SimulatorEmptyState(
          icon: AppIcons.coffee01,
          title: widget.labels.noProducts,
        ),
      );
    }
    return _sectionsPage(context);
  }

  /// صفحة بصف واحد من المقاطع، كما يركّبها `HomePageBody`.
  Widget _sectionsPage(BuildContext context) {
    final feed = widget.feed;
    final labels = widget.labels;
    final banners = feed.publishedBanners;
    final categories = feed.visibleCategories;
    final featured = feed.featured;
    final picks = feed.recommendations();
    final bundles = feed.visibleBundles;
    final promo = feed.promoBanner;
    return ListView(
      // السحب يعمل ولو قصرت الصفحة، كما عند العميل.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
      children: [
        _Section(
          child: SimulatorHomeHeader(labels: labels, now: widget.now),
        ),
        const _Gap(),
        _Section(
          child: SimulatorSearchField(
            value: widget.query,
            hintText: labels.searchHint,
            onChanged: widget.onSearchChanged,
          ),
        ),
        const _Gap(),
        if (banners.isEmpty)
          _Section(child: SimulatorNoBannerNote(label: labels.noBanners))
        else
          SimulatorBannerCarousel(banners: banners),
        const _Gap(),
        if (categories.isNotEmpty)
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SimulatorSectionHeading(
                  title: labels.categories,
                  titleStyle: AppFonts.semiBold18(context),
                  trailingLabel: labels.seeAll,
                  onTapTrailing: () {
                    setState(() => _opened = null);
                    widget.onSeeAllCategories();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SimulatorCategoryMarquee(
                  categories: categories,
                  language: widget.language,
                  onSelect: (category) => widget.onSelectCategory(category.id),
                ),
              ],
            ),
          ),
        const _Gap(),
        if (featured.isNotEmpty)
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SimulatorSectionHeading(
                  title: labels.popular,
                  trailingLabel: labels.viewMore,
                  onTapTrailing: () => setState(() => _opened = _Strip.popular),
                ),
                const SizedBox(height: AppSpacing.lg),
                SimulatorProductStrip(
                  products: featured
                      .take(CustomerFeed.stripCap)
                      .toList(growable: false),
                  language: widget.language,
                ),
              ],
            ),
          ),
        const _Gap(),
        if (promo != null) _Section(child: SimulatorPromoBanner(banner: promo)),
        const _Gap(),
        if (picks.isNotEmpty)
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SimulatorSectionHeading(
                  title: labels.recommendations,
                  subtitle: _seasonalLabel(),
                  trailingLabel: labels.viewMore,
                  onTapTrailing: () =>
                      setState(() => _opened = _Strip.recommendations),
                ),
                const SizedBox(height: AppSpacing.lg),
                SimulatorProductStrip(
                  products: picks,
                  language: widget.language,
                ),
              ],
            ),
          ),
        const _Gap(),
        if (bundles.isNotEmpty)
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SimulatorSectionHeading(title: labels.bundles),
                const SizedBox(height: AppSpacing.sm),
                SimulatorBundleStrip(
                  bundles: bundles,
                  feed: feed,
                  language: widget.language,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// السطر الموسمي يطبعه العميل حين تنجح قراءة الطقس وحدها وحين تكون البركة
  /// قد وصلت، بنص اليوم الحار أو البارد على نفس العتبة.
  String? _seasonalLabel() {
    final feed = widget.feed;
    if (!feed.hasWeather || feed.recommendationPool.isEmpty) return null;
    return feed.isHotDay
        ? widget.labels.hotDayPicks
        : widget.labels.coldDayPicks;
  }

  /// صفحة قائمة مفلترة: حقلها إن كان لها حقل، ثم عنوانها، ثم شبكتها تأخذ بقدر
  /// الهاتف، أو حالة الفراغ وحدها حين لا صفوف. العنوان يبقى فوق الفراغ لأن
  /// «رجوع» الشريط موصَل به، وطرحه يترك الصفحة بلا مخرج.
  Widget _filteredPage({
    required String title,
    required List<PreviewProduct> products,
    required Widget empty,
    String? subtitle,
    String? trailingLabel,
    VoidCallback? onTapTrailing,
    Widget? leading,
  }) {
    final body = products.isEmpty
        ? Center(child: empty)
        : SimulatorProductGrid(products: products, language: widget.language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?leading,
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            leading == null ? AppSpacing.md : AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: SimulatorSectionHeading(
            title: title,
            subtitle: subtitle,
            trailingLabel: trailingLabel,
            onTapTrailing: onTapTrailing,
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// الحافة الجانبية التي يشترك فيها كل مقطع، وهي عند العميل `AppSpacing.lg`.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: child,
    );
  }
}

/// الفاصل بين مقطعين: `AppSpacing.lg` في قائمة العميل.
class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpacing.lg);
}
