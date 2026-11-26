import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/data/bundle_pricing.dart'
    as pricing;
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeBundlesSection extends StatelessWidget {
  const HomeBundlesSection({
    super.key,
    this.title,
    this.showTitle = true,
    this.titleStyle,
  });

  final String? title;
  final bool showTitle;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final bundles = context.watch<HomeCubit>().state.bundles;
    if (bundles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          HomeSectionTitle(
            title: title?.trim().isNotEmpty == true ? title!.trim() : S.bundles,
            titleStyle: titleStyle,
          ),
        SizedBox(height: AppSpacing.sm),
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
    final original = cubit.originalTotalFor(bundle);
    final hasAllProducts =
        bundle.components.isNotEmpty &&
        bundle.components.every(
          (component) =>
              cubit.state.bundleProducts.containsKey(component.productId),
        );
    return Semantics(
      link: true,
      label: bundle.title,
      child: Material(
        color: AppColor.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        child: InkWell(
          onTap: () =>
              Navigator.of(context)
                  .pushNamed(BundleDetailsPage.routeName, arguments: bundle),
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: Container(
            width: AppDimensions.bundleCardWidth,
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColor.cardSurface,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PriceLabel(
                            amount: bundle.price,
                            style: AppFonts.semiBold14(context)
                                .copyWith(color: AppColor.primaryColor),
                            iconSize: AppSizes.px14,
                            iconColor: AppColor.primaryColor,
                          ),
                          if (original > bundle.price)
                            PriceLabel(
                              amount: original,
                              style: AppFonts.regular12(context).copyWith(
                                color: AppColor.greyColor,
                                decoration: TextDecoration.lineThrough,
                              ),
                              iconSize: AppSizes.px12,
                              iconColor: AppColor.greyColor,
                            ),
                          if (original > bundle.price)
                            Text(
                              '${S.youSave}: ${Formatters.price(original - bundle.price)}',
                              style: AppFonts.semiBold12(context)
                                  .copyWith(color: AppColor.primaryColor),
                            ),
                        ],
                      ),
                    ),
                    AnimatedAddToCartIconButton(
                      enabled: hasAllProducts,
                      size: AppDimensions.addToCartButtonCard,
                      onAdd: () async => _addBundle(context, cubit),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addBundle(BuildContext context, HomeCubit home) async {
    final products = home.state.bundleProducts;
    final shares = pricing.bundleShares(bundle, products);
    final components = <CartBundleComponent>[
      for (final component in bundle.components)
        CartBundleComponent(
          productId: component.productId,
          quantity: component.quantity,
          unitPrice:
              shares[component.productId] ??
              products[component.productId]!.price,
        ),
    ];
    final firstProduct = products[bundle.components.first.productId]!;
    context.read<CartCubit>().addBundle(
      bundleId: bundle.id,
      title: bundle.title,
      image: bundle.image.trim().isNotEmpty
          ? bundle.image
          : firstProduct.displayImageUrl ?? firstProduct.image,
      price: bundle.price,
      components: components,
      quantity: 1,
    );
  }
}
