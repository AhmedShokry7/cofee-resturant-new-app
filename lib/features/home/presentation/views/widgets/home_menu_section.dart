import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';

class HomeMenuSection extends StatelessWidget {
  const HomeMenuSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle(title: "All Coffee"),
        SizedBox(height: SpacingTokens.md.h),
        ProductsGridView(
          products: getMenuList(),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }
}
