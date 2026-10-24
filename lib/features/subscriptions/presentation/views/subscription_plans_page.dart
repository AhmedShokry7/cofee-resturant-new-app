import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plan_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_card.dart';

class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key});

  static const routeName = '/subscriptions';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SubscriptionCubit(
        repository: context.read<SubscriptionRepository>(),
      )..load(),
      child: const _SubscriptionPlansView(),
    );
  }
}

class _SubscriptionPlansView extends StatelessWidget {
  const _SubscriptionPlansView();

  String _t(String ar, String en) => AppLocale.instance.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('\u0628\u0627\u0642\u0627\u062A \u0627\u0634\u062A\u0631\u0627\u0643 \u0627\u0644\u0642\u0647\u0648\u0629', 'Coffee subscription plans'))),
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
                  Text(state.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.read<SubscriptionCubit>().load(),
                    child: Text(_t('\u0625\u0639\u0627\u062F\u0629 \u0627\u0644\u0645\u062D\u0627\u0648\u0644\u0629', 'Retry')),
                  ),
                ],
              ),
            );
          }
          if (state.plans.isEmpty) {
            return Center(child: Text(_t('\u0644\u0627 \u062A\u0648\u062C\u062F \u0628\u0627\u0642\u0627\u062A \u0645\u062A\u0627\u062D\u0629 \u062D\u0627\u0644\u064A\u0627\u064B', 'No plans available')));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => CardPaymentCubit(
                          repository: context.read<TapPaymentRepository>(),
                        ),
                        child: CardPaymentPage(
                          subscriptionId: subscription.id,
                          idempotencyKey: subscription.id,
                          amount: plan.price,
                          currency: plan.currencyCode,
                          publicKey: const String.fromEnvironment('TAP_PUBLIC_KEY'),
                          sdkConfiguration: const <String, dynamic>{},
                        ),
                      ),
                    ),
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
