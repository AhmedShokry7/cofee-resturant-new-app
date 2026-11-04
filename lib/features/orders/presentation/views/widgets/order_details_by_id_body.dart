import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_details_by_id/order_details_by_id_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// What the customer sees while, and after, the named order is read.
///
/// An order id can outlive its rows, and the message that carries one may be
/// months old, so the not-found answer is its own state rather than a blank
/// details page: the customer is sent to the list that still holds their
/// orders.
class OrderDetailsByIdBody extends StatelessWidget {
  const OrderDetailsByIdBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderDetailsByIdCubit, OrderDetailsByIdState>(
      builder: (context, state) {
        if (state.signedOut) {
          return const AuthRequiredView(originRoute: OrdersPage.routeName);
        }
        final group = state.order;
        // The details page owns its scaffold and its app bar, so this branch
        // hands it the rows instead of drawing a second frame around it.
        if (group != null && !state.notFound) {
          return OrderDetailsPage(order: group.header, lines: group.lines);
        }
        return Scaffold(
          appBar: AppBar(title: Text(S.orderDetails)),
          body: state.isLoading
              ? const OrdersSkeleton()
              : _UnavailableOrder(
                  message: state.error,
                  onOpenOrders: () =>
                      Navigator.of(context)
                          .pushReplacementNamed(OrdersPage.routeName),
                ),
        );
      },
    );
  }
}

class _UnavailableOrder extends StatelessWidget {
  const _UnavailableOrder({required this.message, required this.onOpenOrders});

  final String? message;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: AppIcons.package,
              title: S.orderNotInAccount,
              subtitle: S.orderNotInAccountHint,
            ),
            if (message != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ],
            SizedBox(height: AppSpacing.md),
            CustomBtn(text: S.myOrders, onPressed: onOpenOrders),
          ],
        ),
      ),
    );
  }
}
