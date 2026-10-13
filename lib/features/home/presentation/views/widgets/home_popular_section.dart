import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/popular_card.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';

class HomePopularSection extends StatelessWidget {
  const HomePopularSection({super.key});

  @override
  Widget build(BuildContext context) {
    final products = getMenuList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle(title: "Popular"),
        SizedBox(height: SpacingTokens.md.h),
        SizedBox(
          height: 210.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.md.w),
            itemBuilder: (context, index) =>
                PopularCard(product: products[index], width: 170),
          ),
        ),
      ],
    );
  }
}
