import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';

class OrdersTabs extends StatelessWidget {
  const OrdersTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<OrdersCubit>().state.status;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.borderColor)),
      ),
      child: Row(
        children: OrderStatus.values
            .map(
              (status) => Expanded(
                child: GestureDetector(
                  onTap: () =>
                      context.read<OrdersCubit>().selectStatus(status),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: SpacingTokens.md.h,
                        ),
                        child: Text(
                          status.label,
                          textAlign: TextAlign.center,
                          style: AppFonts.medium16(context).copyWith(
                            color: current == status
                                ? AppColor.primaryColor
                                : AppColor.greyColor,
                          ),
                        ),
                      ),
                      Container(
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: current == status
                              ? AppColor.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

