import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/discount_badge.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeBundlesSection extends StatelessWidget {
  const HomeBundlesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final bundles = context.watch<HomeCubit>().state.bundles;
    if (bundles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(title: S.bundles),
        SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppDimensions.bundleSectionHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: bundles.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) =>
                _BundleCard(bundle: bundles[index]),
          ),
        ),
      ],
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle});

  final BundleModel bundle;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    final products = cubit.productsIn(bundle);
    final imageProduct = products.isEmpty ? null : products.first;
    final savingPercent = cubit.savingPercentFor(bundle);
    return GestureDetector(
      onTap: () =>
          Navigator.of(context)
              .pushNamed(BundleDetailsPage.routeName, arguments: bundle),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: AppDimensions.bundleCardWidth,
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColor.whiteColor,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(color: AppColor.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.cardRadius,
                    ),
                    child: imageProduct == null
                        ? const SizedBox.shrink()
                        : SizedBox.expand(
                            child: ProductImageView(product: imageProduct),
                          ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  bundle.title,
                  style: AppFonts.semiBold14(context),
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
                        amount: cubit.originalTotalFor(bundle),
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
