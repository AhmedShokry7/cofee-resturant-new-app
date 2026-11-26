import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_marquee.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_link.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The category row of the home page: one line of circles that keeps walking.
class HomeCategoriesSection extends StatelessWidget {
  const HomeCategoriesSection({
    super.key,
    this.title,
    this.showTitle = true,
    this.titleStyle,
  });

  final String? title;
  final bool showTitle;
  final TextStyle? titleStyle;

  /// Opens the products of one category, not the catalogue tab.
  ///
  /// The id travels on the page and is resolved by the cubit, never written to
  /// the shared tab index: a category tapped here used to move the tab the
  /// customer had left open, and going back from the products was impossible
  /// because the page was the tab. Pushing gives the arrow a page to return to.
  void _openCategory(BuildContext context, String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoriesPage(initialCategoryId: categoryId),
      ),
    );
  }

  /// Opens the root of the category tree: every main category, no products.
  ///
  /// Nothing is selected here on purpose. The page carries no category id, so
  /// a tab selected on a previous visit has no way of turning this into a
  /// product page.
  void _openAllCategories(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CategoriesPage.all()));
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<HomeCubit>().state.categories;
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          HomeSectionTitle(
            title: title?.trim().isNotEmpty == true
                ? title!.trim()
                : S.categories,
            titleStyle: titleStyle ?? AppFonts.semiBold18(context),
            trailing: HomeSectionLink(
              label: S.seeAll,
              onTap: () => _openAllCategories(context),
            ),
          ),
        SizedBox(height: AppSpacing.md),
        CategoryMarquee(
          categories: categories,
          onTap: (category) => _openCategory(context, category.id),
        ),
      ],
    );
  }
}
