import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/home/presentation/views/see_all_products_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/popular_card.dart';

class HomeProductsCarousel extends StatelessWidget {
  const HomeProductsCarousel({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
    this.maxItems = 10,
    this.showViewMore = false,
  });

  final String title;
  final String? subtitle;
  final List<ProductModel> products;
  final int maxItems;
  final bool showViewMore;

  void _openAll(BuildContext context) {
    Navigator.of(context).pushNamed(
      SeeAllProductsPage.routeName,
      arguments: SeeAllProductsArgs(
        title: title,
        subtitle: subtitle,
        products: products,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = products.length > maxItems
        ? products.sublist(0, maxItems)
        : products;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: title,
          trailing: showViewMore
              ? GestureDetector(
                  onTap: () => _openAll(context),
                  child: Text(
                    "View more",
                    style: AppFonts.medium12(
                      context,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                )
              : null,
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4.h),
          Text(
            subtitle!,
            style: AppFonts.regular12(
              context,
            ).copyWith(color: AppColor.greyColor),
          ),
        ],
        SizedBox(height: SpacingTokens.md.h),
        SizedBox(
          height: 210.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayed.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.md.w),
            itemBuilder: (context, index) =>
                PopularCard(product: displayed[index], width: 170),
          ),
        ),
      ],
    );
  }
}
