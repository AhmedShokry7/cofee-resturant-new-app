import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_marquee.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_link.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The category row of the home page: one line of circles that keeps walking.
class HomeCategoriesSection extends StatelessWidget {
  const HomeCategoriesSection({super.key});

  /// Opens the catalogue tab on the chip the customer was looking at.
  ///
  /// Matched by stable id, not by position: the home row and the categories tab
  /// load independently, so equal indices do not guarantee equal categories.
  void _openCategory(BuildContext context, String? categoryId) {
    if (categoryId == null) return;
    context.read<CategoriesCubit>().selectCategoryById(categoryId);
    context.read<MainCubit>().changeTab(MainTab.categories.index);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<HomeCubit>().state.categories;
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: S.categories,
          titleStyle: AppFonts.semiBold18(context),
          trailing: HomeSectionLink(
            label: S.seeAll,
            onTap: () =>
                context.read<MainCubit>().changeTab(MainTab.categories.index),
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
