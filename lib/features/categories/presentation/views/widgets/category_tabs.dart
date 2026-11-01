import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs({super.key});

  @override
  Widget build(BuildContext context) {
    // Categories now come from the cubit. The old version called
    // getCategoriesList() here, which meant the tabs were fixed at compile time
    // and could never reflect an admin change.
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        final categories = state.categories;
        if (categories.isEmpty) {
          // While the first page loads, shimmer tab pills keep the
          // [AppDimensions.tabBarHeight] bar laid out exactly as the loaded
          // tabs will be.
          if (state.isLoading) return const CategoryTabsSkeleton();
          return SizedBox(height: AppDimensions.tabBarHeight);
        }

        final current = state.index.clamp(0, categories.length - 1);

        return Container(
          height: AppDimensions.tabBarHeight,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColor.borderColor)),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemBuilder: (context, index) {
              final isSelected = index == current;
              return GestureDetector(
                onTap: () => context.read<CategoriesCubit>().select(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              categories[index].label,
                              style: AppFonts.medium16(context).copyWith(
                                color: isSelected
                                    ? AppColor.primaryColor
                                    : AppColor.greyColor,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: AppSizes.px3,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColor.primaryColor
                                : AppColor.transparent,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppRadius.r8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
