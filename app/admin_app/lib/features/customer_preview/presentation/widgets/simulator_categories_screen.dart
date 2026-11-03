import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_bundle_strip.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_category_tabs.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_empty_state.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_grid.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// تبويب التصنيفات كما يبنيه تطبيق العميل: عنوان في وسط الأعلى، ثم شريط
/// الأسماء، ثم جسم التصنيف المختار.
///
/// تصنيف الباقات يستثني نفسه: جسمه قائمة باقات لا شبكة منتجات، لأن الباقة لا
/// صفّ لها في جدول المنتجات — وهي القاعدة نفسها التي يمشي بها `CategoryBody`.
/// المحاكي لا يقلب تبويبًا ولا يستدعي صفحة: القائمة تُقرأ مما وصل اللوحة فعلًا.
class SimulatorCategoriesScreen extends StatelessWidget {
  const SimulatorCategoriesScreen({
    super.key,
    required this.feed,
    required this.language,
    required this.labels,
    required this.category,
    required this.products,
    required this.onSelectCategory,
  });

  final CustomerFeed feed;
  final AppLanguage language;
  final SimulatorLabels labels;

  /// التصنيف المعروض الآن، أو null حين لا تصنيف في القاعدة أصلًا.
  final AdminCategory? category;
  final List<PreviewProduct> products;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final categories = feed.visibleCategories;
    if (categories.isEmpty) {
      return SimulatorEmptyState(
        icon: AppIcons.gridView,
        title: labels.noCategories,
        subtitle: labels.categoriesHint,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // عنوان الصفحة كما عند العميل: في وسط السطر، بستة عشر على الجوانب.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Text(
            labels.categories,
            textAlign: TextAlign.center,
            style: AppFonts.semiBold20(context)
                .copyWith(color: adminHeadingColor(Theme.of(context))),
          ),
        ),
        SimulatorCategoryTabs(
          categories: categories,
          selectedId: category?.id,
          language: language,
          onSelect: (value) => onSelectCategory(value.id),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (CustomerFeed.isBundlesCategory(category)) return _bundles(context);
    if (products.isEmpty) {
      return SimulatorEmptyState(
        icon: AppIcons.coffee01,
        title: labels.noProducts,
        subtitle: category == null
            ? null
            : labels.productsIn(category!.nameFor(language)),
      );
    }
    return SimulatorProductGrid(products: products, language: language);
  }

  Widget _bundles(BuildContext context) {
    final bundles = feed.visibleBundles;
    if (bundles.isEmpty) {
      return SimulatorEmptyState(
        icon: AppIcons.package02,
        title: labels.noBundles,
        subtitle: labels.bundlesHint,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: bundles.length,
      itemBuilder: (context, index) => SimulatorBundleListTile(
        bundle: bundles[index],
        original: feed.bundleOriginalTotal(bundles[index]),
        language: language,
      ),
    );
  }
}
