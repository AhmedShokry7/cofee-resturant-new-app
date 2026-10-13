import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/popular_card.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_description.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class ProductDetailsBody extends StatelessWidget {
  const ProductDetailsBody({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final related = getMenuList()
        .where((item) => item.id != product.id)
        .toList();
    return ListView(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Image.asset(
              product.image,
              height: 220.h,
              width: 220.w,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: SpacingTokens.lg.h),
        Text(
          product.category,
          style: AppFonts.regular14(context).copyWith(color: AppColor.greyColor),
        ),
        SizedBox(height: 4.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(product.name, style: AppFonts.semiBold20(context)),
            ),
            SizedBox(width: SpacingTokens.sm.w),
            Text(
              Formatters.price(product.price),
              style: AppFonts.semiBold18(
                context,
              ).copyWith(color: AppColor.primaryColor),
            ),
          ],
        ),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Product Details", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.sm.h),
        ProductDescription(description: product.description),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Products you may like", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        SizedBox(
          height: 210.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.md.w),
            itemBuilder: (context, index) =>
                PopularCard(product: related[index], width: 170),
          ),
        ),
      ],
    );
  }
}
