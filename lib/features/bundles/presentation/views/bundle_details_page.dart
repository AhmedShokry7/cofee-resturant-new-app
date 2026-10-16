import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/manager/bundle_details/bundle_details_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class BundleDetailsPage extends StatelessWidget {
  const BundleDetailsPage({super.key, required this.bundle});

  static const routeName = "bundleDetailsRoute";

  final BundleModel bundle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BundleDetailsCubit(
        repository: context.read<CatalogRepository>(),
        bundle: bundle,
        branchId: context.read<BranchCubit>().state.selected?.id,
      ),
      child: Builder(
        builder: (context) => BlocListener<BranchCubit, BranchState>(
          listenWhen: (previous, current) =>
              previous.selected?.id != current.selected?.id,
          listener: (context, state) =>
              context.read<BundleDetailsCubit>().setBranch(state.selected?.id),
          child: Scaffold(
            appBar: AppBar(title: Text(bundle.title)),
            body: const _BundleDetailsBody(),
            bottomNavigationBar: Container(
              padding: EdgeInsets.all(SpacingTokens.lg.w),
              decoration: const BoxDecoration(
                color: AppColor.whiteColor,
                border: Border(top: BorderSide(color: AppColor.borderColor)),
              ),
              child: BlocBuilder<BundleDetailsCubit, BundleDetailsState>(
                builder: (context, state) => CustomBtn(
                  text: S.addBundleToCart,
                  onPressed: state.products.isEmpty
                      ? null
                      : () => _addBundle(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addBundle(BuildContext context) {
    final cubit = context.read<BundleDetailsCubit>();
    final shares = cubit.sharesFor();
    final cart = context.read<CartCubit>();
    for (final product in cubit.state.products) {
      final component = bundle.components.firstWhere(
        (item) => item.productId == product.id,
      );
      cart.add(
        product,
        quantity: component.quantity,
        note: S.bundleNote(bundle.title),
        unitPrice: shares[product.id],
      );
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.addedBundleToCart(bundle.title))));
  }
}

class _BundleDetailsBody extends StatelessWidget {
  const _BundleDetailsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BundleDetailsCubit, BundleDetailsState>(
      builder: (context, state) {
        if (state.isLoading && state.products.isEmpty) {
          return const BundleDetailsSkeleton();
        }
        if (state.error != null && state.products.isEmpty) {
          return Center(child: Text(state.error!));
        }

        final cubit = context.read<BundleDetailsCubit>();
        final imageProduct = state.products.isEmpty
            ? null
            : state.products.first;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.lg.w,
            SpacingTokens.md.h,
            SpacingTokens.lg.w,
            SpacingTokens.lg.w,
          ),
          children: [
            if (imageProduct != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    height: 200.h,
                    width: double.infinity,
                    child: ProductImageView(product: imageProduct),
                  ),
                ),
              ),
            SizedBox(height: SpacingTokens.lg.h),
            Text(state.bundle.title, style: AppFonts.semiBold20(context)),
            SizedBox(height: 4.h),
            Text(
              state.bundle.subtitle,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            Text(S.whatsInside, style: AppFonts.semiBold16(context)),
            SizedBox(height: SpacingTokens.sm.h),
            for (final product in state.products)
              Container(
                margin: EdgeInsets.only(bottom: SpacingTokens.sm.h),
                padding: EdgeInsets.all(SpacingTokens.sm.w),
                decoration: BoxDecoration(
                  color: AppColor.whiteColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColor.borderColor),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: SizedBox(
                        height: 48.w,
                        width: 48.w,
                        child: ProductImageView(product: product),
                      ),
                    ),
                    SizedBox(width: SpacingTokens.sm.w),
                    Expanded(
                      child: Text(
                        product.name,
                        style: AppFonts.medium14(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PriceLabel(
                      amount: product.price,
                      style: AppFonts.semiBold14(context)
                          .copyWith(color: AppColor.greyColor),
                      iconSize: 14,
                      iconColor: AppColor.greyColor,
                    ),
                  ],
                ),
              ),
            SizedBox(height: SpacingTokens.md.h),
            _PriceRow(
              label: S.originalTotal,
              amount: cubit.originalTotalFor(),
              struck: true,
            ),
            SizedBox(height: SpacingTokens.xs.h),
            _PriceRow(
              label: S.bundlePrice,
              amount: state.bundle.price,
              highlighted: true,
            ),
            SizedBox(height: SpacingTokens.xs.h),
            _PriceRow(
              label: S.youSave,
              amount: cubit.savingsFor(),
              highlighted: true,
            ),
          ],
        );
      },
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.struck = false,
    this.highlighted = false,
  });

  final String label;
  final double amount;
  final bool struck;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppFonts.semiBold16(context).copyWith(
      color: highlighted ? AppColor.primaryColor : AppColor.blackColor,
      decoration: struck ? TextDecoration.lineThrough : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.regular14(context)
              .copyWith(color: AppColor.greyColor),
        ),
        PriceLabel(
          amount: amount,
          style: valueStyle,
          iconSize: valueStyle.fontSize,
          iconColor: valueStyle.color,
        ),
      ],
    );
  }
}
