import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
    final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.removedFromCart(item.product.name)),
        duration: MotionTokens.messageHold,
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
    // Snackbars with actions may remain visible indefinitely when accessibility
    // navigation is enabled; close this undo snackbar on the same length the
    // snackbar was given, so the two never disagree about when it is over.
    Timer(MotionTokens.messageHold, snackBarController.close);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<CartCubit, CartState>(
          // A cart that could not be saved on the server must say so: a
          // silent failure would show a change that only exists on this
          // device.
          listenWhen: (previous, current) =>
              current.error != null && current.error != previous.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.error!)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(title: S.cart),
              Expanded(
                child: BlocBuilder<CartCubit, CartState>(
                  builder: (context, state) {
                    if (state.isLoading && state.items.isEmpty) {
                      return const CartLinesSkeleton();
                    }
                    if (state.isEmpty) {
                      return EmptyState(
                        icon: AppIcons.cart,
                        title: S.cartEmpty,
                        subtitle: S.cartEmptyHint,
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: AppLayout.pageBody,
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
                                onTap: item.isBundle
                                    ? () => _openBundle(context, item.bundleId!)
                                    : null,
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
      ),
    );
  }

  Future<void> _openBundle(BuildContext context, String bundleId) async {
    try {
      final bundle = await context.read<CatalogRepository>().getBundleById(
        bundleId,
      );
      if (!context.mounted || bundle == null) return;
      Navigator.of(context)
          .pushNamed(BundleDetailsPage.routeName, arguments: bundle);
    } catch (_) {
      // The line remains usable if the bundle was unpublished after it was
      // added; opening details is best-effort and must not mutate the cart.
    }
  }
}

class _CartSummary extends StatefulWidget {
  const _CartSummary();

  @override
  State<_CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends State<_CartSummary> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        final total = cart.total;
        return Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColor.whiteColor,
            border: Border.all(color: AppColor.borderColor),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.r16),
              topRight: Radius.circular(AppRadius.r16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryRow(label: S.total, priceValue: total, total: true),
              SizedBox(height: AppSpacing.md),
              CustomBtn(
                text: S.proceedToCheckout,
                borderRadius: AppRadius.r32,
                onPressed: () =>
                    Navigator.of(context).pushNamed(CheckoutPage.routeName),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.priceValue,
    this.total = false,
  });

  final String label;
  final bool total;

  /// Monetary value rendered with the standard currency icon.
  final double priceValue;

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
          style: valueStyle,
          iconSize: valueStyle.fontSize,
          iconColor: valueStyle.color,
        ),
      ],
    );
  }
}
