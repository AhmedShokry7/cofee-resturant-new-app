import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class EReceiptPage extends StatelessWidget {
  const EReceiptPage({super.key});

  static const routeName = "eReceiptRoute";

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutCubit>().state;
    final order = state.lastOrder;

    return Scaffold(
      appBar: AppBar(title: const Text("E-Receipt")),
      body: order == null
          ? const EmptyState(
              icon: HugeIcons.strokeRoundedReceiptDollar,
              title: "No receipt yet",
              subtitle: "Your latest order receipt will appear here",
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.lg.w,
                SpacingTokens.md.h,
                SpacingTokens.lg.w,
                SpacingTokens.lg.w,
              ),
              children: [
                _ReceiptCard(order: order),
                SizedBox(height: SpacingTokens.lg.h),
                _InfoCard(
                  label: "Payment Method",
                  value: state.selectedPaymentMethod.label,
                ),
                SizedBox(height: SpacingTokens.md.h),
                _InfoCard(
                  label: "Shipping Address",
                  value:
                      "${state.selectedAddress.label} - ${state.selectedAddress.details}",
                ),
              ],
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedReceiptDollar,
                size: 24.w,
                color: AppColor.primaryColor,
              ),
              SizedBox(width: SpacingTokens.sm.w),
              Expanded(
                child: Text(
                  "E-Receipt",
                  style: AppFonts.semiBold18(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: SpacingTokens.sm.w),
              Text(
                order.id,
                style: AppFonts.medium14(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Text(
            Formatters.date(order.date),
            style: AppFonts.regular14(
              context,
            ).copyWith(color: AppColor.greyColor),
          ),
          SizedBox(height: SpacingTokens.md.h),
          const Divider(),
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.sm.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${item.quantity} × ${item.product.name}",
                      style: AppFonts.regular14(context),
                    ),
                  ),
                  Text(
                    Formatters.price(item.total),
                    style: AppFonts.medium14(context),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          SizedBox(height: SpacingTokens.sm.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total", style: AppFonts.semiBold16(context)),
              Text(
                Formatters.price(order.total),
                style: AppFonts.semiBold18(
                  context,
                ).copyWith(color: AppColor.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.regular12(
              context,
            ).copyWith(color: AppColor.greyColor),
          ),
          SizedBox(height: 4.h),
          Text(value, style: AppFonts.medium14(context)),
        ],
      ),
    );
  }
}
