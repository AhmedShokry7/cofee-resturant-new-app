import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';

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
          // While the first page loads, shimmer tab pills keep the 50.h bar
          // laid out exactly as the loaded tabs will be.
          if (state.isLoading) return const CategoryTabsSkeleton();
          return SizedBox(height: 50.h);
        }

        final current = state.index.clamp(0, categories.length - 1);

        return Container(
          height: 50.h,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColor.borderColor)),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: EdgeInsets.symmetric(horizontal: SpacingTokens.md.w),
            itemBuilder: (context, index) {
              final isSelected = index == current;
              return GestureDetector(
                onTap: () => context.read<CategoriesCubit>().select(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: SpacingTokens.md.w),
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
                          height: 3.h,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColor.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(8.r),
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
