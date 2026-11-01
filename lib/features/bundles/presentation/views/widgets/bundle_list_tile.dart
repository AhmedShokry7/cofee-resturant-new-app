import 'package:flutter/material.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/data/bundle_pricing.dart'
    as pricing;
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/shared/widgets/discount_badge.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Full-width bundle row for vertical lists (e.g. the Bundles tab).
class BundleListTile extends StatelessWidget {
  const BundleListTile({super.key, required this.bundle, this.productsById});

  final BundleModel bundle;

  /// Already-loaded catalogue rows. Callers that have them should pass them so
  /// one tile does not issue its own query.
  final Map<String, ProductModel>? productsById;

  @override
  Widget build(BuildContext context) {
    final byId = productsById ?? const <String, ProductModel>{};
    final products = pricing.bundleProducts(bundle, byId);
    final imageProduct = products.isEmpty ? null : products.first;
    // Without the loaded catalogue there is nothing to compare the bundle
    // price against, so the tile shows its own price and no saving badge.
    final savingPercent = productsById == null
        ? 0
        : pricing.bundleSavingPercent(bundle, byId);
    final original = productsById == null
        ? bundle.price
        : pricing.bundleOriginalTotal(bundle, byId);
    return GestureDetector(
      onTap: () =>
          Navigator.of(context)
              .pushNamed(BundleDetailsPage.routeName, arguments: bundle),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColor.whiteColor,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(color: AppColor.borderColor),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.cardRadius,
                      ),
                      child: imageProduct == null
                          ? SizedBox(
                              width: AppSizes.px78,
                              height: AppSizes.px78,
                            )
                          : SizedBox(
                              height: AppSizes.px78,
                              width: AppSizes.px78,
                              child: ProductImageView(product: imageProduct),
                            ),
                    ),
                  ],
                ),
                SizedBox(width: AppSpacing.md),
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
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        bundle.subtitle,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xs),
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
                          SizedBox(width: AppSpacing.xs),
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
                  DirectionAwareIcons.forward(context),
                  size: AppSizes.px20,
                  color: AppColor.greyColor,
                ),
              ],
            ),
          ),
          if (savingPercent > 0)
            PositionedDirectional(
              top: DiscountBadge.cardTop,
              end: DiscountBadge.cardRight,
              child: DiscountBadge(
                percent: savingPercent,
                size: DiscountBadge.cardSize,
              ),
            ),
        ],
      ),
    );
  }
}
