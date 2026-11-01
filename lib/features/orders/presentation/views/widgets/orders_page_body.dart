import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_card.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/orders_tabs.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
              if (state.isLoading && state.orders.isEmpty) {
                return const OrdersSkeleton();
              }
              if (state.signedOut) {
                return _SignInRequired(
                  onSignIn: () => Navigator.of(context).pushNamed(
                    AuthPage.routeName,
                    arguments: OrdersPage.routeName,
                  ),
                  onRetry: () => context.read<OrdersCubit>().refresh(),
                );
              }
              if (state.error != null && state.orders.isEmpty) {
                return _OrdersError(
                  message: state.error!,
                  onRetry: () => context.read<OrdersCubit>().refresh(),
                );
              }
              final orders = state.grouped;
              if (orders.isEmpty) {
                return EmptyState(
                  icon: AppIcons.package,
                  title: S.noOrders,
                  subtitle: S.ordersEmptyHint,
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<OrdersCubit>().refresh(),
                child: ListView.builder(
                  padding: AppLayout.pageBody,
                  itemCount: orders.length,
                  itemBuilder: (context, index) =>
                      OrderCard(order: orders[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({required this.onSignIn, required this.onRetry});

  final VoidCallback onSignIn;
  final VoidCallback onRetry;

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
              title: S.signInToSeeOrders,
              subtitle: S.orderHistoryAccount,
            ),
            SizedBox(height: AppSpacing.md),
            CustomBtn(text: S.signIn, onPressed: onSignIn),
            SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(S.retry)),
          ],
        ),
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(icon: AppIcons.package, title: S.couldNotLoadOrders),
            SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: AppSpacing.md),
            CustomBtn(text: S.tryAgain, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
