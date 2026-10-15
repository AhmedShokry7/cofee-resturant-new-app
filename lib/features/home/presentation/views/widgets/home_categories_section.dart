import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_grid_item.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';

class HomeCategoriesSection extends StatelessWidget {
  const HomeCategoriesSection({super.key});

  static const int _columns = 4;
  static const int _rows = 2;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<HomeCubit>().state.categories;
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Categories", style: AppFonts.semiBold18(context)),
            GestureDetector(
              onTap: () => context.read<MainCubit>().changeTab(1),
              child: Text(
                "See all",
                style: AppFonts.medium12(
                  context,
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        SizedBox(height: SpacingTokens.lg.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = SpacingTokens.sm.w;
            final itemWidth =
                (constraints.maxWidth - (_columns - 1) * gap) / _columns;
            final itemHeight = itemWidth * 1.2;
            return SizedBox(
              height: itemHeight * _rows + SpacingTokens.md.h,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _rows,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: SpacingTokens.md.h,
                  mainAxisExtent: itemWidth,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) => CategoryGridItem(
                  category: categories[index],
                  onTap: () {
                    context.read<CategoriesCubit>().select(index);
                    context.read<MainCubit>().changeTab(1);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

