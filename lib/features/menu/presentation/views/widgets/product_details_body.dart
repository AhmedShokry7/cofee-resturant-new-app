import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/product_variants.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/cup_icon.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/popular_card.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_description.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class ProductDetailsBody extends StatelessWidget {
  const ProductDetailsBody({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final extras = extrasFor(product);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
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
            BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
              builder: (context, state) {
                final selected = extras
                    .where((extra) => state.extraIds.contains(extra.id))
                    .toList();
                return Text(
                  Formatters.price(
                    unitPrice(
                      product,
                      size: hasSizes(product) ? state.size : null,
                      extras: selected,
                    ),
                  ),
                  style: AppFonts.semiBold18(
                    context,
                  ).copyWith(color: AppColor.primaryColor),
                );
              },
            ),
          ],
        ),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Product Details", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.sm.h),
        ProductDescription(description: product.description),
        if (hasSizes(product)) ...[
          SizedBox(height: SpacingTokens.lg.h),
          const _SizeSection(),
        ],
        if (hasSugarChoice(product)) ...[
          SizedBox(height: SpacingTokens.lg.h),
          const _SugarSection(),
        ],
        if (extras.isNotEmpty) ...[
          SizedBox(height: SpacingTokens.lg.h),
          _ExtrasSection(extras: extras),
        ],
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Goes well with", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        _GoesWellWith(product: product),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: SpacingTokens.sm.h),
      child: Text(text, style: AppFonts.semiBold16(context)),
    );
  }
}

class _SizeSection extends StatelessWidget {
  const _SizeSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle("Size"),
            Row(
                children: [
                  for (var i = 0; i < DrinkSize.values.length; i++) ...[
                    if (i > 0) SizedBox(width: SpacingTokens.sm.w),
                    Expanded(
                      child: _OptionChip(
                        label: DrinkSize.values[i].label,
                        hint: DrinkSize.values[i].priceDelta == 0
                            ? null
                            : '+${Formatters.price(DrinkSize.values[i].priceDelta)}',
                        icon: CupIcon(
                          size: DrinkSize.values[i],
                          selected:
                              state.size == DrinkSize.values[i],
                        ),
                        selected: state.size == DrinkSize.values[i],
                        onTap: () => context
                            .read<ProductDetailsCubit>()
                            .selectSize(DrinkSize.values[i]),
                      ),
                    ),
                  ],
                ],
            ),
          ],
        );
      },
    );
  }
}

class _SugarSection extends StatelessWidget {
  const _SugarSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle("Sugar"),
            Wrap(
              spacing: SpacingTokens.sm.w,
              runSpacing: SpacingTokens.sm.h,
              children: [
                for (final level in SugarLevel.values)
                  _OptionChip(
                    label: level.label,
                    selected: state.sugar == level,
                    onTap: () => context
                        .read<ProductDetailsCubit>()
                        .selectSugar(level),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ExtrasSection extends StatelessWidget {
  const _ExtrasSection({required this.extras});

  final List<ProductExtra> extras;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle("Extras"),
            for (final extra in extras)
              _ExtraTile(
                extra: extra,
                selected: state.extraIds.contains(extra.id),
                onTap: () => context
                    .read<ProductDetailsCubit>()
                    .toggleExtra(extra.id),
              ),
          ],
        );
      },
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.icon,
  });

  final String label;
  final String? hint;
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            if (icon != null) ...[
              icon!,
              SizedBox(height: 4.h),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.medium14(context).copyWith(
                color: selected
                    ? AppColor.primaryColor
                    : AppColor.blackColor,
              ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: AppFonts.regular12(context).copyWith(
                  color: selected
                      ? AppColor.primaryColor
                      : AppColor.greyColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExtraTile extends StatelessWidget {
  const _ExtraTile({
    required this.extra,
    required this.selected,
    required this.onTap,
  });

  final ProductExtra extra;
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
                color: selected
                    ? AppColor.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: selected
                      ? AppColor.primaryColor
                      : AppColor.greyColor,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 16.w, color: AppColor.whiteColor)
                  : null,
            ),
            SizedBox(width: SpacingTokens.sm.w),
            Expanded(
              child: Text(extra.name, style: AppFonts.medium14(context)),
            ),
            Text(
              '+${Formatters.price(extra.price)}',
              style: AppFonts.semiBold14(
                context,
              ).copyWith(color: AppColor.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoesWellWith extends StatelessWidget {
  const _GoesWellWith({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final paired = pairingsFor(product);
    if (paired.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 210.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paired.length,
        separatorBuilder: (context, index) =>
            SizedBox(width: SpacingTokens.md.w),
        itemBuilder: (context, index) =>
            PopularCard(product: paired[index], width: 170),
      ),
    );
  }
}
