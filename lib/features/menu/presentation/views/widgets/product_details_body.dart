import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/product_options.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/cup_icon.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_description.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/quantity_stepper.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class ProductDetailsBody extends StatelessWidget {
  const ProductDetailsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        if (state.isLoading) {
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

        final groups = state.groups;
        final surface = Theme.of(context).brightness == Brightness.dark
            ? AppColor.darkSurface
            : AppColor.whiteColor;
        const overlap = 28.0;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                height: 300.h,
                child: ProductImageView(product: product),
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: Offset(0, -overlap),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
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
                    SpacingTokens.lg.h,
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
                            child: Text(
                              product.name,
                              style: AppFonts.semiBold20(context),
                            ),
                          ),
                          SizedBox(width: SpacingTokens.sm.w),
                          PriceLabel(
                            amount: context.read<ProductDetailsCubit>().unitPrice,
                            style: AppFonts.semiBold18(context)
                                .copyWith(color: AppColor.primaryColor),
                            iconSize: 18,
                            iconColor: AppColor.primaryColor,
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
                            onIncrement: () => context
                                .read<ProductDetailsCubit>()
                                .incrementQuantity(),
                            onDecrement: () => context
                                .read<ProductDetailsCubit>()
                                .decrementQuantity(),
                          ),
                        ],
                      ),
                      SizedBox(height: SpacingTokens.lg.h),
                      Text(S.productDetails, style: AppFonts.semiBold16(context)),
                      SizedBox(height: SpacingTokens.sm.h),
                      ProductDescription(description: product.description),

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

                      SizedBox(height: SpacingTokens.xxl.h),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: overlap + SpacingTokens.xxl.h),
            ),
          ],
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(SpacingTokens.xs.w),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40.w,
            height: 40.w,
            child: Icon(icon, size: 20.w, color: color ?? Colors.white),
          ),
        ),
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
