import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/add_card_tile.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_option_tile.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

class PaymentMethodPageBody extends StatelessWidget {
  const PaymentMethodPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SavedCardsCubit, SavedCardsState>(
      listenWhen: (previous, current) => previous.cards != current.cards,
      listener: (context, saved) {
        final checkout = context.read<CheckoutCubit>();
        if (checkout.state.selectedSavedCard != null || saved.cards.isEmpty)
          return;
        final card = saved.cards.firstWhere(
          (item) => item.isDefault,
          orElse: () => saved.cards.first,
        );
        checkout.selectSavedCard(card);
      },
      child: BlocBuilder<CheckoutCubit, CheckoutState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            children: [
              const _PayableTotal(),
              SizedBox(height: SpacingTokens.lg.h),
              Text(S.creditDebitCard, style: AppFonts.semiBold16(context)),
              SizedBox(height: SpacingTokens.md.h),
              AddCardTile(
                onTap: () =>
                    Navigator.of(context).pushNamed(AddCardPage.routeName),
              ),
              // Saved cards first, so a customer who already saved one sees it
              // before anything else. Selecting one makes the checkout charge it
              // directly instead of asking for the number again.
              BlocBuilder<SavedCardsCubit, SavedCardsState>(
                builder: (context, saved) {
                  if (saved.cards.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: SpacingTokens.sm.h),
                      Text(
                        S.payWithSavedCard,
                        style: AppFonts.medium14(context),
                      ),
                      SizedBox(height: SpacingTokens.sm.h),
                      for (final card in saved.cards)
                        _SavedCardRow(
                          card: card,
                          selected: state.selectedSavedCard?.id == card.id,
                          onTap: () =>
                              context.read<CheckoutCubit>().selectSavedCard(
                                state.selectedSavedCard?.id == card.id
                                    ? null
                                    : card,
                              ),
                        ),
                    ],
                  );
                },
              ),
              SizedBox(height: SpacingTokens.xl.h),
              Text(S.morePaymentOptions, style: AppFonts.semiBold16(context)),
              SizedBox(height: SpacingTokens.md.h),
              ...state.paymentMethods.map(
                (method) => PaymentOptionTile(
                  method: method,
                  selected: state.selectedPaymentMethod?.id == method.id,
                  onTap: () =>
                      context.read<CheckoutCubit>().selectPaymentMethod(method),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SavedCardRow extends StatelessWidget {
  const _SavedCardRow({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SavedCardModel card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColor.primaryColor : AppColor.greyColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpacingTokens.xs.h),
        child: Row(
          children: [
            Icon(
              selected
                  ? HugeIcons.strokeRoundedRadioButton
                  : HugeIcons.strokeRoundedRadioButton,
              size: 20.w,
              color: accent,
            ),
            SizedBox(width: SpacingTokens.sm.w),
            Expanded(
              child: Text(
                '${card.brand.label.isEmpty ? S.cardBrandFallback : card.brand.label}  ****${card.last4}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.medium14(context).copyWith(color: accent),
              ),
            ),
            SizedBox(width: SpacingTokens.xs.w),
            Text(
              '${S.cardExpires} ${card.expiry}',
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayableTotal extends StatelessWidget {
  const _PayableTotal();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        final checkout = context.watch<CheckoutCubit>();
        final summary = checkout.summary(cart.total);
        if (checkout.state.quoteLoading) {
          return Container(
            padding: EdgeInsets.all(SpacingTokens.md.w),
            decoration: BoxDecoration(
              color: AppColor.lightGreyColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Container(
          padding: EdgeInsets.all(SpacingTokens.md.w),
          decoration: BoxDecoration(
            color: AppColor.lightGreyColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.totalToPay,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
              checkout.state.checkoutQuote == null
                  ? Text(S.orderFailed, style: AppFonts.regular14(context))
                  : PriceLabel(
                      amount: summary.total,
                      style: AppFonts.semiBold18(context)
                          .copyWith(color: AppColor.primaryColor),
                      iconSize: 18,
                      iconColor: AppColor.primaryColor,
                    ),
            ],
          ),
        );
      },
    );
  }
}
