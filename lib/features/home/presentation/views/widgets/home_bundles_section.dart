import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/discount_badge.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

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
        SizedBox(height: SpacingTokens.md.h),
        SizedBox(
          height: 210.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: bundles.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.md.w),
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
    final products = context.read<HomeCubit>().productsIn(bundle);
    final imageProduct = products.isEmpty ? null : products.first;
    return GestureDetector(
      onTap: () =>
          Navigator.of(context)
              .pushNamed(BundleDetailsPage.routeName, arguments: bundle),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 170.w,
            padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: imageProduct == null
                    ? const SizedBox.shrink()
                    : SizedBox.expand(
                        child: ProductImageView(product: imageProduct),
                      ),
              ),
            ),
            SizedBox(height: SpacingTokens.sm.h),
            Text(
              bundle.title,
              style: AppFonts.semiBold14(context),
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
                    amount: context.read<HomeCubit>().originalTotalFor(bundle),
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
        if (context.read<HomeCubit>().originalTotalFor(bundle) > bundle.price)
          Positioned(
            top: DiscountBadge.cardTop,
            right: DiscountBadge.cardRight,
            child: DiscountBadge(
              percent: (((context.read<HomeCubit>().originalTotalFor(bundle) - bundle.price) /
                      context.read<HomeCubit>().originalTotalFor(bundle)) *
                  100)
                  .round(),
              size: DiscountBadge.cardSize,
            ),
          ),
      ],
    ),
  );
  }
}
