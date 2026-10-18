import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/cart/presentation/views/widgets/coupon_breakdown.dart';
import 'package:new_coffee/features/cart/presentation/views/widgets/promo_code_field.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  /// Minus on the last piece removes the line, with an Undo snackbar
  /// instead of a blocking warning (fast to use, forgiving on mistakes).
  void _decrementOrRemove(BuildContext context, CartItem item) {
    final cart = context.read<CartCubit>();
    if (item.quantity > 1) {
      cart.decrementLine(item.lineId);
      return;
    }
    cart.decrementLine(item.lineId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.removedFromCart(item.product.name)),
        action: SnackBarAction(
          label: S.undo,
          onPressed: () {
            if (item.isBundle) {
              cart.addBundle(
                bundleId: item.bundleId!,
                title: item.product.name,
                image: item.product.image,
                price: item.product.price,
                components: item.bundleComponents,
                quantity: item.quantity,
                note: item.note,
                optionValueIds: item.optionValueIds,
              );
            } else {
              cart.add(
                item.product,
                quantity: item.quantity,
                note: item.note,
                optionValueIds: item.optionValueIds,
                unitPrice: item.unitPrice,
                bundleId: item.bundleId,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageTitle(title: S.cart),
            Expanded(
              child: BlocBuilder<CartCubit, CartState>(
                builder: (context, state) {
                  if (state.isEmpty) {
                    return EmptyState(
                      icon: HugeIcons.strokeRoundedShoppingCart01,
                      title: S.cartEmpty,
                      subtitle: S.cartEmptyHint,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            SpacingTokens.lg.w,
                            SpacingTokens.md.h,
                            SpacingTokens.lg.w,
                            SpacingTokens.lg.w,
                          ),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return ProductCard(
                              product: item.product,
                              quantity: item.quantity,
                              showFavorite: false,
                              note: item.note,
                              lineId: item.lineId,
                              unitPrice: item.unitPrice,
                              onIncrement: () => context
                                  .read<CartCubit>()
                                  .incrementLine(item.lineId),
                              onDecrement: () =>
                                  _decrementOrRemove(context, item),
                            );
                          },
                        ),
                      ),
                      const _CartSummary(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatefulWidget {
  const _CartSummary();

  @override
  State<_CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends State<_CartSummary> {
  final _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromo() async {
    FocusScope.of(context).unfocus();
    final checkout = context.read<CheckoutCubit>();
    final applied = await checkout.applyCoupon(
      _promoController.text,
      items: context.read<CartCubit>().state.items,
    );
    if (!mounted) return;
    final message = applied
        ? S.couponApplied
        : checkout.state.couponError ?? S.invalidCouponCode;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (applied) _promoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        return BlocBuilder<CheckoutCubit, CheckoutState>(
          builder: (context, checkoutState) {
            final checkout = context.read<CheckoutCubit>();
            final summary = checkout.summary(cart.total);
            final subtotal = summary.subtotal;
            final discount = summary.discount;
            final total = summary.total;
            return Container(
              padding: EdgeInsets.all(SpacingTokens.lg.w),
              decoration: BoxDecoration(
                color: AppColor.whiteColor,
                border: Border.all(color: AppColor.borderColor),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (checkoutState.appliedCoupon == null)
                    PromoCodeField(
                      controller: _promoController,
                      onApply: _applyPromo,
                      // Shown inline as well as in the snackbar: a refusal the
                      // customer has to dismiss before re-reading is not a
                      // reason. `couponError` persists until the next attempt.
                      error: checkoutState.couponError,
                      // Clearing the box must also drop the applied discount,
                      // or the customer keeps paying it with nothing on screen
                      // to explain it.
                      onClear: () =>
                          context.read<CheckoutCubit>().removeCoupon(),
                    )
else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AppliedCouponRow(
                        code: checkoutState.appliedCoupon!.coupon.code,
                        scopeLabel:
                            checkoutState.appliedCoupon!.coupon.isScoped
                            ? checkoutState.appliedCoupon!.coupon.scopeLabel
                            : '',
                        onRemove: () =>
                            context.read<CheckoutCubit>().removeCoupon(),
                      ),
                      CouponBreakdown(coupon: checkoutState.appliedCoupon!),
                    ],
                  ),
                  SizedBox(height: SpacingTokens.md.h),
                  _SummaryRow(label: S.subTotal, priceValue: subtotal),
                  SizedBox(height: SpacingTokens.xs.h),
                  _SummaryRow(
                    label: S.deliveryFee,
                    priceValue: summary.deliveryFee,
                  ),
                  if (discount > 0) ...[
                    SizedBox(height: SpacingTokens.xs.h),
                    _SummaryRow(
                      label: S.discount,
                      priceValue: discount,
                      pricePrefix: '-',
                    ),
                  ],
                  SizedBox(height: SpacingTokens.sm.h),
                  const Divider(height: 1),
                  SizedBox(height: SpacingTokens.sm.h),
                  _SummaryRow(
                    label: S.totalCost,
                    priceValue: total,
                    total: true,
                  ),
                  SizedBox(height: SpacingTokens.md.h),
                  CustomBtn(
                    text: S.proceedToCheckout,
                    borderRadius: 32.r,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(CheckoutPage.routeName),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AppliedCouponRow extends StatelessWidget {
  const _AppliedCouponRow({
    required this.code,
    required this.onRemove,
    this.scopeLabel = '',
  });

  final String code;
  final VoidCallback onRemove;

  /// What the coupon is limited to, when it is limited. Empty for an unscoped
  /// coupon, which needs no explanation.
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.md.w,
        vertical: SpacingTokens.sm.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: AppFonts.medium14(context)
                      .copyWith(color: AppColor.primaryColor),
                ),
                // The discount below is a share of these items only, so the
                // figure looks small next to the subtotal. Naming the scope
                // here is the difference between "the coupon worked" and "the
                // coupon is broken".
                if (scopeLabel.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '$scopeLabel — ${S.couponScopeDiscountNote}',
                    style: AppFonts.regular12(context).copyWith(
                      color: AppColor.greyColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 20.w, color: AppColor.primaryColor),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.priceValue,
    this.total = false,
    this.pricePrefix = '',
  });

  final String label;
  final bool total;

  /// Monetary value rendered with the standard currency icon.
  final double priceValue;

  /// Literal prepended to [priceValue] (`-` for discounts).
  final String pricePrefix;

  @override
  Widget build(BuildContext context) {
    final valueStyle =
        (total ? AppFonts.semiBold16(context) : AppFonts.regular16(context))
            .copyWith(
              color: total ? AppColor.primaryColor : AppColor.blackColor,
            );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              (total ? AppFonts.medium16(context) : AppFonts.regular16(context))
                  .copyWith(color: AppColor.greyColor),
        ),
        PriceLabel(
          amount: priceValue,
          prefix: pricePrefix,
          style: valueStyle,
          iconSize: valueStyle.fontSize,
          iconColor: valueStyle.color,
        ),
      ],
    );
  }
}
