import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plan_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_card.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key});

  static const routeName = '/subscriptions';

  /// Two columns, and a picture that takes the upper half of the cell.
  ///
  /// The card lays itself out against exactly this shape, so the ratio belongs
  /// beside the grid that uses it rather than inside the card.
  static const SliverGridDelegate gridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.6,
      );

  @override
  Widget build(BuildContext context) {
    // The plans read only through `subscriptions.list_plans`, which the server
    // grants to `authenticated` (083). A guest would get a permission error and
    // a retry that can never work, so the shared prompt comes first and no
    // request is made at all.
    return AuthGuard(
      child: BlocProvider(
        create: (context) => SubscriptionCubit(
          repository: context.read<SubscriptionRepository>(),
          branchId: context.read<BranchCubit>().state.selected?.id,
        )..load(),
        // Plans are sold per branch (083 filters on `p_branch_id`), and the
        // selector is on the shell under this page: choosing another branch
        // while the plans are open has to re-ask, or the customer is shown
        // prices for a branch they no longer stand at.
        child: BlocListener<BranchCubit, BranchState>(
          listenWhen: (previous, current) =>
              previous.selected?.id != current.selected?.id,
          listener: (context, state) =>
              context.read<SubscriptionCubit>().setBranch(state.selected?.id),
          child: const _SubscriptionPlansView(),
        ),
      ),
    );
  }
}

class _SubscriptionPlansView extends StatelessWidget {
  const _SubscriptionPlansView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.subscriptionPlans)),
      body: BlocBuilder<SubscriptionCubit, SubscriptionState>(
        builder: (context, state) {
          if (state.loading && state.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.loadError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.couldNotLoadPlans, textAlign: TextAlign.center),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.read<SubscriptionCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              ),
            );
          }
          if (state.plans.isEmpty) {
            return Center(child: Text(S.noPlansAvailable));
          }
          return GridView.builder(
            padding: EdgeInsets.all(AppSpacing.md),
            gridDelegate: SubscriptionPlansPage.gridDelegate,
            itemCount: state.plans.length,
            itemBuilder: (context, index) {
              final plan = state.plans[index];
              return SubscriptionPlanCard(
                plan: plan,
                onTap: () => Navigator.of(context).pushNamed(
                  SubscriptionPlanDetailsPage.routeName,
                  arguments: plan,
                ),
                // A write in flight makes this cell's answer unknown: a second
                // tap could open a payment for a subscription the first one is
                // still creating.
                busy: state.isMutating,
                onSubscribe: () => _subscribe(context, plan),
              );
            },
          );
        },
      ),
    );
  }

  /// Starts the plan and pays for it, in that order.
  ///
  /// The subscription the payment is opened for is the one this call created.
  /// Reading it back out of the cubit's state could pick up a subscription the
  /// customer already had, which would charge the new plan's price to the old
  /// subscription's id.
  Future<void> _subscribe(BuildContext context, SubscriptionPlan plan) async {
    final cubit = context.read<SubscriptionCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final subscription = await cubit.subscribe(plan);
    if (subscription == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(S.couldNotStartSubscription)),
      );
      return;
    }
    if (!context.mounted) return;
    CardPaymentPage.pushForSubscription(
      context,
      subscriptionId: subscription.id,
      amount: plan.price,
      currency: plan.currencyCode,
    );
  }
}
