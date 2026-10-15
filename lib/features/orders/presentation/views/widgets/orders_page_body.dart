import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_card.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/orders_tabs.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
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
                if (state.isLoading && state.orders.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.signedOut) {
                  return _SignInRequired(
                    onSignIn: () => Navigator.of(context).pushNamed(
                      AuthPage.routeName,
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

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({required this.onSignIn, required this.onRetry});

  final VoidCallback onSignIn;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
              icon: HugeIcons.strokeRoundedPackage,
              title: 'Sign in to see your orders',
              subtitle: 'Order history belongs to your account',
            ),
            SizedBox(height: SpacingTokens.md.h),
            CustomBtn(text: 'Sign in', onPressed: onSignIn),
            SizedBox(height: SpacingTokens.sm.h),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
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
        padding: EdgeInsets.all(SpacingTokens.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
              icon: HugeIcons.strokeRoundedPackage,
              title: 'Could not load orders',
            ),
            SizedBox(height: SpacingTokens.sm.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context).copyWith(
                color: AppColor.greyColor,
              ),
            ),
            SizedBox(height: SpacingTokens.md.h),
            CustomBtn(text: 'Try again', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

