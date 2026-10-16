import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/product_options.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/cup_icon.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_description.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class ProductDetailsBody extends StatelessWidget {
  const ProductDetailsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        final product = state.product;
        if (product == null) {
          // Loading and failing are different states: the first shows a
          // progress indicator, only the second shows a message.
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Text(
              state.error ?? 'Product unavailable',
              style: AppFonts.regular14(context),
            ),
          );
        }

        final groups = state.groups;

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
                child: SizedBox(
                  height: 220.h,
                  width: 220.w,
                  child: ProductImageView(product: product),
                ),
              ),
            ),
            SizedBox(height: SpacingTokens.lg.h),
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
                Text(
                  Formatters.price(
                    context.read<ProductDetailsCubit>().unitPrice,
                  ),
                  style: AppFonts.semiBold18(context)
                      .copyWith(color: AppColor.primaryColor),
                ),
              ],
            ),
            if (!state.isAvailable) ...[
              SizedBox(height: SpacingTokens.sm.h),
              _UnavailableBanner(reason: state.unavailableReason),
            ],
            SizedBox(height: SpacingTokens.lg.h),
            Text("Product Details", style: AppFonts.semiBold16(context)),
            SizedBox(height: SpacingTokens.sm.h),
            ProductDescription(description: product.description),

            // Every group is rendered from what the admin configured. The old
            // page had exactly three hardcoded sections and matched them on
            // category names, so a product with a different set of options could
            // not be configured at all.
            for (final group in groups) ...[
              SizedBox(height: SpacingTokens.lg.h),
              _OptionGroupSection(
                group: group,
                selection: state.selection,
                showCupArt: group.code == 'size',
                cupSize: cupSizeFor(groups, state.selection),
              ),
            ],

            SizedBox(height: SpacingTokens.lg.h),
            const Divider(),
          ],
        );
      },
    );
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ar = AppLocale.instance.isArabic;
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
              reason ??
                  (ar
                      ? 'هذا الخيار غير متوفر حاليًا'
                      : 'This combination is not available right now'),
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
    final ar = AppLocale.instance.isArabic;
    final name = group.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppFonts.semiBold16(context)),
        if (group.minSelect > 0)
          Padding(
            padding: EdgeInsets.only(top: 2.h, bottom: SpacingTokens.xs.h),
            child: Text(
              ar ? 'مطلوب' : 'Required',
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          )
        else
          SizedBox(height: SpacingTokens.xs.h),
        // A single-select group with a handful of values reads better as chips
        // in a row; multi-select groups are a checklist.
        if (group.isSingleSelect)
          Row(
            children: [
              for (var i = 0; i < group.values.length; i++) ...[
                if (i > 0) SizedBox(width: SpacingTokens.sm.w),
                Expanded(
                  child: _ValueChip(
                    label: _label(group.values[i]),
                    hint: _hint(group.values[i]),
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
              hint: _hint(value),
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

  static String? _hint(OptionValue value) =>
      value.priceDelta == 0 ? null : '+${Formatters.price(value.priceDelta)}';
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
            if (icon != null) ...[icon!, SizedBox(height: 4.h)],
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.medium14(context).copyWith(
                color: selected ? AppColor.primaryColor : AppColor.blackColor,
              ),
            ),
            if (hint != null)
              Text(
                hint!,
                style: AppFonts.regular12(context).copyWith(
                  color: selected ? AppColor.primaryColor : AppColor.greyColor,
                ),
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
  final String? hint;
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
              Text(
                hint!,
                style: AppFonts.semiBold14(context)
                    .copyWith(color: AppColor.primaryColor),
              ),
          ],
        ),
      ),
    );
  }
}
