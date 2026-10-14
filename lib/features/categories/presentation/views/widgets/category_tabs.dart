import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/categories/data/categories_list.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = getCategoriesList();
    final current = context.watch<CategoriesCubit>().state.index;
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
  }
}

