import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_card.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/orders_tabs.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class OrdersPageBody extends StatelessWidget {
  const OrdersPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OrdersTabs(),
        Expanded(
          child: BlocBuilder<OrdersCubit, OrdersState>(
            builder: (context, state) {
              final orders = state.filtered;
              if (orders.isEmpty) {
                return const EmptyState(
                  icon: HugeIcons.strokeRoundedPackage,
                  title: "No orders here",
                  subtitle: "Your orders in this status will appear here",
                );
              }
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  SpacingTokens.lg.w,
                  SpacingTokens.md.h,
                  SpacingTokens.lg.w,
                  SpacingTokens.lg.w,
                ),
                itemCount: orders.length,
                itemBuilder: (context, index) =>
                    OrderCard(order: orders[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
