import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/product_options.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/cup_icon.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_description.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/quantity_stepper.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/discount_badge.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// Premium collapsing product page.
///
/// The hero picture is pinned behind the content; the details sheet is a
/// rounded card that scrolls up and progressively covers the picture. The
/// header controls live in the transparent [AppBar] that overlays the hero.
class ProductDetailsBody extends StatelessWidget {
  const ProductDetailsBody({super.key, required this.controller});

  /// Owned by the page so the app bar can react to the same scroll position
  /// (it fades the product name in as the hero is covered).
  final ScrollController controller;

  /// How far the details sheet climbs over the hero when the page is at rest.
  static const double _overlap = 28.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        if (state.isLoading && state.product == null) {
          return const ProductDetailsSkeleton();
        }
        final product = state.product;
        if (product == null) {
          return Center(
            child: Text(
              state.error ?? S.productUnavailable,
              style: AppFonts.regular14(context),
            ),
          );
        }

        final surface = Theme.of(context).brightness == Brightness.dark
            ? AppColor.darkSurface
            : AppColor.whiteColor;
        final heroHeight = 300.h;

        return Stack(
          children: [
            // The picture stays put behind the sheet; only the sheet moves, so
            // the hero is covered from the bottom up instead of scrolling away.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _CollapsingHero(
                product: product,
                height: heroHeight,
                controller: controller,
              ),
            ),
            Positioned.fill(
              child: CustomScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Transparent strip the height of the visible hero, so the
                  // sheet starts life overlapping the picture by [_overlap].
                  SliverToBoxAdapter(
                    child: SizedBox(height: heroHeight - _overlap),
                  ),
                  SliverToBoxAdapter(
                    child: _DetailsSheet(
                      product: product,
                      state: state,
                      groups: state.groups,
                      surface: surface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-bleed hero that drifts up slightly as the sheet scrolls over it, so
/// the picture feels like a backdrop rather than a static block.
class _CollapsingHero extends StatelessWidget {
  const _CollapsingHero({
    required this.product,
    required this.height,
    required this.controller,
  });

  final ProductModel product;
  final double height;
  final ScrollController controller;

  /// Fraction of the scroll distance the picture drifts by. Kept low so the
  /// movement reads as subtle depth, not a sliding panel.
  static const double _parallaxFactor = 0.35;

  /// Upper bound on the drift so the picture can never expose a gap below it.
  static const double _maxParallaxRatio = 0.2;

  @override
  Widget build(BuildContext context) {
    final maxParallax = height * _maxParallaxRatio;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final offset = controller.hasClients ? controller.offset : 0.0;
            final shift = (offset * _parallaxFactor).clamp(0.0, maxParallax);
            return Transform.translate(offset: Offset(0, -shift), child: child);
          },
          // Taller than the box so the drift never reveals empty space.
          child: SizedBox(
            width: double.infinity,
            height: height + maxParallax,
            child: ProductImageView(product: product),
          ),
        ),
      ),
    );
  }
}

/// The rounded info card that overlaps the hero and holds everything the user
/// configures: category, title, price, quantity, description, options and the
/// companion products carousel.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.product,
    required this.state,
    required this.groups,
    required this.surface,
  });

  final ProductModel product;
  final ProductDetailsState state;
  final List<OptionGroup> groups;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductDetailsCubit>();

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.lg.h,
        SpacingTokens.lg.w,
        SpacingTokens.xxl.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.category,
            style: AppFonts.regular14(context)
                .copyWith(color: AppColor.greyColor),
          ),
          SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(product.name, style: AppFonts.semiBold20(context)),
              ),
              SizedBox(width: SpacingTokens.sm.w),
              // The price the customer pays, the discount the server applied
              // and the price before it.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PriceLabel(
                        amount: cubit.unitPrice,
                        style: AppFonts.semiBold18(context)
                            .copyWith(color: AppColor.primaryColor),
                        iconSize: 18,
                        iconColor: AppColor.primaryColor,
                      ),
                      if (cubit.hasDiscount) ...[
                        SizedBox(width: 4.w),
                        DiscountBadge(
                          percent: cubit.discountPercentage.round(),
                          size: 30,
                        ),
                      ],
                    ],
                  ),
                  if (cubit.hasDiscount)
                    Text(
                      Formatters.amount(cubit.regularPrice!),
                      style: AppFonts.regular12(context).copyWith(
                        color: AppColor.greyColor,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (!state.isAvailable) ...[
            SizedBox(height: SpacingTokens.sm.h),
            _UnavailableBanner(reason: state.unavailableReason),
          ],
          SizedBox(height: SpacingTokens.lg.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  S.quantity,
                  style: AppFonts.semiBold16(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              QuantityStepper(
                quantity: state.quantity,
                onIncrement: () =>
                    context.read<ProductDetailsCubit>().incrementQuantity(),
                onDecrement: () =>
                    context.read<ProductDetailsCubit>().decrementQuantity(),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.lg.h),
          Text(S.productDetails, style: AppFonts.semiBold16(context)),
          SizedBox(height: SpacingTokens.sm.h),
          ProductDescription(description: product.description),

          ...[
            SizedBox(height: SpacingTokens.md.h),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  size: 18.w,
                  color: AppColor.greyColor,
                ),
                SizedBox(width: SpacingTokens.xs.w),
                Text(
                  product.calories == null
                      ? S.caloriesUnavailable
                      : S.caloriesValue(product.calories!),
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            ),
          ],

          for (final group in groups) ...[
            SizedBox(height: SpacingTokens.lg.h),
            _OptionGroupSection(
              group: group,
              selection: state.selection,
              showCupArt: group.code == 'size',
              cupSize: cupSizeFor(groups, state.selection),
            ),
          ],

          if (state.pairs.isNotEmpty) ...[
            SizedBox(height: SpacingTokens.xl.h),
            HomeProductsCarousel(
              title: S.goesWellWith,
              products: state.pairs,
              maxItems: 5,
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18.w, color: AppColor.errorColor),
          SizedBox(width: SpacingTokens.sm.w),
          Expanded(
            child: Text(
              reason ?? S.unavailableNow,
              style: AppFonts.medium14(context)
                  .copyWith(color: AppColor.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionGroupSection extends StatelessWidget {
  const _OptionGroupSection({
    required this.group,
    required this.selection,
    required this.showCupArt,
    required this.cupSize,
  });

  final OptionGroup group;
  final OptionSelection selection;
  final bool showCupArt;
  final CupSize cupSize;

  @override
  Widget build(BuildContext context) {
    final name = group.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppFonts.semiBold16(context)),
        if (group.minSelect > 0)
          Padding(
            padding: EdgeInsets.only(top: 2.h, bottom: SpacingTokens.xs.h),
            child: Text(
              S.required,
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          )
        else
          SizedBox(height: SpacingTokens.xs.h),
        if (group.isSingleSelect)
          Row(
            children: [
              for (var i = 0; i < group.values.length; i++) ...[
                if (i > 0) SizedBox(width: SpacingTokens.sm.w),
                Expanded(
                  child: _ValueChip(
                    label: _label(group.values[i]),
                    hint: _delta(group.values[i]),
                    selected: selection
                        .inGroup(group.id)
                        .contains(group.values[i].id),
                    icon: showCupArt
                        ? CupIcon(
                            size: CupSize.fromCode(group.values[i].code),
                            selected: selection
                                .inGroup(group.id)
                                .contains(group.values[i].id),
                          )
                        : null,
                    onTap: () => context
                        .read<ProductDetailsCubit>()
                        .toggleValue(group.id, group.values[i].id),
                  ),
                ),
              ],
            ],
          )
        else
          for (final value in group.values)
            _ValueTile(
              label: _label(value),
              hint: _delta(value),
              selected: selection.inGroup(group.id).contains(value.id),
              onTap: () => context.read<ProductDetailsCubit>().toggleValue(
                group.id,
                value.id,
              ),
            ),
      ],
    );
  }

  static String _label(OptionValue value) => value.name;

  static double? _delta(OptionValue value) =>
      value.priceDelta == 0 ? null : value.priceDelta;
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.icon,
  });

  final String label;
  final double? hint;
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hintAmount = hint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.md.w,
          vertical: SpacingTokens.sm.h,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColor.primaryColor.withValues(alpha: 0.1)
              : AppColor.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColor.primaryColor : AppColor.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, SizedBox(height: 4.h)],
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.medium14(context).copyWith(
                color: selected ? AppColor.primaryColor : AppColor.blackColor,
              ),
            ),
            if (hintAmount != null)
              PriceLabel(
                amount: hintAmount,
                prefix: '+',
                style: AppFonts.regular12(context).copyWith(
                  color: selected ? AppColor.primaryColor : AppColor.greyColor,
                ),
                iconSize: 12,
                iconColor: selected
                    ? AppColor.primaryColor
                    : AppColor.greyColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final double? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: SpacingTokens.sm.h),
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.md.w,
          vertical: SpacingTokens.sm.h,
        ),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColor.primaryColor : AppColor.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 22.w,
              width: 22.w,
              decoration: BoxDecoration(
                color: selected ? AppColor.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: selected ? AppColor.primaryColor : AppColor.greyColor,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 16.w, color: AppColor.whiteColor)
                  : null,
            ),
            SizedBox(width: SpacingTokens.sm.w),
            Expanded(child: Text(label, style: AppFonts.medium14(context))),
            if (hint != null)
              PriceLabel(
                amount: hint!,
                prefix: '+',
                style: AppFonts.semiBold14(context)
                    .copyWith(color: AppColor.primaryColor),
                iconSize: 13,
                iconColor: AppColor.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}
