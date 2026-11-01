import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
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
import 'package:new_coffee/core/theme/tokens.dart';

class CheckoutPageBody extends StatefulWidget {
  const CheckoutPageBody({super.key});

  @override
  State<CheckoutPageBody> createState() => _CheckoutPageBodyState();
}

class _CheckoutPageBodyState extends State<CheckoutPageBody> {
  StreamSubscription<CartState>? _cartSubscription;
  StreamSubscription<CheckoutState>? _checkoutSubscription;
  bool _quoteScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cartSubscription != null) return;
    final cart = context.read<CartCubit>();
    final checkout = context.read<CheckoutCubit>();
    _cartSubscription = cart.stream.listen((state) => _scheduleQuote());
    _checkoutSubscription = checkout.stream.listen((state) => _scheduleQuote());
    _scheduleQuote();
  }

  void _scheduleQuote() {
    if (_quoteScheduled || !mounted) return;
    _quoteScheduled = true;
    scheduleMicrotask(() {
      _quoteScheduled = false;
      if (!mounted) return;
      context.read<CheckoutCubit>().refreshCheckoutQuote(
        context.read<CartCubit>().state.items,
      );
    });
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _checkoutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppLayout.pageBody,
      children: [
        Text(S.pickupBranch, style: AppFonts.semiBold16(context)),
        SizedBox(height: AppSpacing.md),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: BranchSelector(),
        ),
        SizedBox(height: AppSpacing.lg),
        const Divider(),
        SizedBox(height: AppSpacing.lg),
        const DeliveryFulfillmentSection(),
        SizedBox(height: AppSpacing.lg),
        const Divider(),
        SizedBox(height: AppSpacing.lg),
        const ShippingAddressSection(),
        SizedBox(height: AppSpacing.lg),
        const Divider(),
        SizedBox(height: AppSpacing.lg),
        Text(S.orderList, style: AppFonts.semiBold16(context)),
        SizedBox(height: AppSpacing.md),
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
        SizedBox(height: AppSpacing.md),
        const _CouponSection(),
        SizedBox(height: AppSpacing.md),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              style: AppFonts.medium14(context)
                  .copyWith(color: AppColor.primaryColor),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              AppIcons.close,
              size: AppSizes.px20,
              color: AppColor.primaryColor,
            ),
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
            final summary = cubit.summary(cart.total, cart.items);
            final total = summary.total;
            if (checkout.checkoutQuote == null) {
              if (checkout.quoteError == null && !checkout.quoteLoading) {
                return const SizedBox.shrink();
              }
              if (checkout.quoteLoading) {
                return Column(
                  children: [
                    LabeledValueRow(
                      label: S.deliveryFee,
                      priceValue: summary.deliveryFee,
                    ),
                    LabeledValueRow(
                      label: S.total,
                      priceValue: total,
                      emphasized: true,
                      big: true,
                    ),
                    if (summary.tax == 0)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            S.vatIncluded,
                            style: AppFonts.regular12(context)
                                .copyWith(color: AppColor.greyColor),
                          ),
                        ),
                      ),
                  ],
                );
              }
              return TextButton.icon(
                onPressed: () => cubit.refreshCheckoutQuote(cart.items),
                icon: const Icon(AppIcons.refresh),
                label: Text(S.retry),
              );
            }
            return Column(
              children: [
                // The price before the product discount, so the two rows below
                // it add up to the subtotal the customer is charged.
                if (summary.productDiscount > 0) ...[
                  LabeledValueRow(
                    label: S.subtotal,
                    priceValue: summary.subtotal + summary.productDiscount,
                  ),
                  LabeledValueRow(
                    label: S.productDiscount,
                    priceValue: summary.productDiscount,
                    pricePrefix: '-',
                    emphasized: true,
                  ),
                ],
                if (summary.discount > 0)
                  LabeledValueRow(
                    label: S.discount,
                    priceValue: summary.discount,
                    pricePrefix: '-',
                    emphasized: true,
                  ),
                LabeledValueRow(
                  label: S.deliveryFee,
                  priceValue: summary.deliveryFee,
                ),
                if (summary.tax > 0)
                  LabeledValueRow(label: S.vat, priceValue: summary.tax),
                LabeledValueRow(
                  label: S.total,
                  priceValue: total,
                  emphasized: true,
                  big: true,
                ),
                if (summary.tax == 0)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        S.vatIncluded,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
