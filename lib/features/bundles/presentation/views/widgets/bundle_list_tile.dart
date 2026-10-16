import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/data/bundle_pricing.dart'
    as pricing;
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// Full-width bundle row for vertical lists (e.g. the Bundles tab).
class BundleListTile extends StatelessWidget {
  const BundleListTile({super.key, required this.bundle, this.productsById});

  final BundleModel bundle;

  /// Already-loaded catalogue rows. Callers that have them should pass them so
  /// one tile does not issue its own query.
  final Map<String, ProductModel>? productsById;

  @override
  Widget build(BuildContext context) {
    final products = productsById == null
        ? const <ProductModel>[]
        : pricing.bundleProducts(bundle, productsById!);
    final imageProduct = products.isEmpty ? null : products.first;
    final original = productsById == null
        ? bundle.price
        : pricing.bundleOriginalTotal(bundle, productsById!);
    return GestureDetector(
      onTap: () =>
          Navigator.of(context)
              .pushNamed(BundleDetailsPage.routeName, arguments: bundle),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
        padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: imageProduct == null
                  ? SizedBox(width: 64.w, height: 64.w)
                  : SizedBox(
                      height: 64.w,
                      width: 64.w,
                      child: ProductImageView(product: imageProduct),
                    ),
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bundle.title,
                    style: AppFonts.semiBold16(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    bundle.subtitle,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Flexible(
                        child: PriceLabel(
                          amount: bundle.price,
                          style: AppFonts.semiBold14(context)
                              .copyWith(color: AppColor.primaryColor),
                          iconSize: 14,
                          iconColor: AppColor.primaryColor,
                        ),
                      ),
                      SizedBox(width: SpacingTokens.xs.w),
                      Flexible(
                        child: PriceLabel(
                          amount: original,
                          style: AppFonts.regular12(context).copyWith(
                            color: AppColor.greyColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                          iconSize: 12,
                          iconColor: AppColor.greyColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              HugeIcons.strokeRoundedArrowRight01,
              size: 20.w,
              color: AppColor.greyColor,
            ),
          ],
        ),
      ),
    );
  }
}
