import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/branch/presentation/views/widgets/branch_selector.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/delivery_fulfillment_section.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_address_section.dart';
import 'package:new_coffee/features/cart/presentation/views/widgets/promo_code_field.dart';
import 'package:new_coffee/features/cart/presentation/views/widgets/coupon_breakdown.dart';
import 'package:new_coffee/shared/widgets/labeled_value_row.dart';

class CheckoutPageBody extends StatelessWidget {
  const CheckoutPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        Text(S.pickupBranch, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: BranchSelector(),
        ),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        const DeliveryFulfillmentSection(),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        const ShippingAddressSection(),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text(S.orderList, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            return Column(
              children: state.items
                  .map(
                    (item) => OrderItemCard(
                      product: item.product,
                      quantity: item.quantity,
                      note: item.note,
                      unitPrice: item.unitPrice,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        SizedBox(height: SpacingTokens.md.h),
        const _CouponSection(),
        SizedBox(height: SpacingTokens.md.h),
        const _OrderSummary(),
      ],
    );
  }
}

class _CouponSection extends StatefulWidget {
  const _CouponSection();

  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  final _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    FocusScope.of(context).unfocus();
    final checkout = context.read<CheckoutCubit>();
    final cart = context.read<CartCubit>();
    final applied = await checkout.applyCoupon(
      _promoController.text,
      items: cart.state.items,
    );
    if (!mounted) return;
    final message = applied
        ? S.couponApplied
        : checkout.state.couponError ?? S.invalidCouponCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (applied) _promoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        if (state.appliedCoupon == null) {
          return PromoCodeField(
            controller: _promoController,
            onApply: _apply,
            error: state.couponError,
            onClear: () => context.read<CheckoutCubit>().removeCoupon(),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppliedCouponRow(
              code: state.appliedCoupon!.coupon.code,
              scopeLabel: state.appliedCoupon!.coupon.isScoped
                  ? state.appliedCoupon!.coupon.scopeLabel
                  : '',
              onRemove: () => context.read<CheckoutCubit>().removeCoupon(),
            ),
            CouponBreakdown(coupon: state.appliedCoupon!),
          ],
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
            child: Text(
              code,
              style: AppFonts.medium14(context).copyWith(color: AppColor.primaryColor),
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

class _OrderSummary extends StatelessWidget {
  const _OrderSummary();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        return BlocBuilder<CheckoutCubit, CheckoutState>(
          builder: (context, checkout) {
            final cubit = context.read<CheckoutCubit>();
            final summary = cubit.summary(cart.total);
            final subtotal = summary.subtotal;
            final total = summary.total;
            final saved = summary.discount;
            return Column(
              children: [
                LabeledValueRow(label: S.subtotal, priceValue: subtotal),
                SizedBox(height: SpacingTokens.xs.h),
                LabeledValueRow(
                  label: S.deliveryFee,
                  priceValue: summary.deliveryFee,
                ),
                if (saved > 0) ...[
                  SizedBox(height: SpacingTokens.xs.h),
                  LabeledValueRow(
                    label: S.couponDiscount,
                    priceValue: saved,
                    pricePrefix: '-',
                    emphasized: true,
                  ),
                ],
                SizedBox(height: SpacingTokens.xs.h),
                LabeledValueRow(
                  label: S.total,
                  priceValue: total,
                  emphasized: true,
                  big: true,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
