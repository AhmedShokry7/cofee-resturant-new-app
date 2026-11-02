import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plan_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_card.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key});

  static const routeName = '/subscriptions';

  @override
  Widget build(BuildContext context) {
    // The plans read only through `subscriptions.list_plans`, which the server
    // grants to `authenticated` (083). A guest would get a permission error and
    // a retry that can never work, so the shared prompt comes first and no
    // request is made at all.
    return AuthGuard(
      child: BlocProvider(
        create: (context) =>
            SubscriptionCubit(
              repository: context.read<SubscriptionRepository>(),
            )..load(),
        child: const _SubscriptionPlansView(),
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
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
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
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.6,
            ),
            itemCount: state.plans.length,
            itemBuilder: (context, index) {
              final plan = state.plans[index];
              return SubscriptionPlanCard(
                plan: plan,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubscriptionPlanDetailsPage(plan: plan),
                  ),
                ),
                onSubscribe: () async {
                  final cubit = context.read<SubscriptionCubit>();
                  await cubit.subscribe(plan);
                  if (!context.mounted) return;
                  final subscription = cubit.state.subscription;
                  if (subscription == null) return;
                  CardPaymentPage.pushForSubscription(
                    context,
                    subscriptionId: subscription.id,
                    amount: plan.price,
                    currency: plan.currencyCode,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
