import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_detail_row.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_image.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SubscriptionPlanDetailsPage extends StatelessWidget {
  const SubscriptionPlanDetailsPage({super.key, required this.plan});

  final SubscriptionPlan plan;

  static const routeName = '/subscription-plan-details';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SubscriptionCubit(
          repository: context.read<SubscriptionRepository>(),
        );
        // A plan that covers every product has no list to read, so the page
        // asks only for the one it can show.
        if (plan.coversSelectedProducts) cubit.loadPlanProducts(plan.id);
        return cubit;
      },
      child: _PlanDetailsView(plan: plan),
    );
  }
}

class _PlanDetailsView extends StatelessWidget {
  const _PlanDetailsView({required this.plan});

  final SubscriptionPlan plan;

  /// Starts the plan and pays for it, in that order.
  ///
  /// The subscription the payment is opened for is the row this call created.
  /// Reading it back out of the cubit's state could pick up a subscription the
  /// customer already had, which would charge this plan's price to that other
  /// subscription's id.
  Future<void> _subscribe(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name.isEmpty ? S.planDetails : plan.name),
      ),
      body: BlocBuilder<SubscriptionCubit, SubscriptionState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.all(AppSpacing.lg),
            children: [
              if (plan.imageUrl != null && plan.imageUrl!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: SubscriptionPlanImage(imageUrl: plan.imageUrl!),
                ),
              Text(plan.name, style: AppFonts.semiBold20(context)),
              if (plan.description.isNotEmpty) ...[
                SizedBox(height: AppSpacing.sm),
                Text(plan.description, style: AppFonts.regular14(context)),
              ],
              SizedBox(height: AppSpacing.md),
              SubscriptionDetailRow(
                label: S.priceLabel,
                value: Formatters.price(plan.price, plan.currencyCode),
              ),
              SubscriptionDetailRow(
                label: S.durationLabel,
                value: S.daysCount(plan.durationDays),
              ),
              SubscriptionDetailRow(
                label: S.cupsPerCycle,
                value: S.cupsCount(plan.cupsPerCycle),
              ),
              SubscriptionDetailRow(
                label: S.rolloverCap,
                value: S.cupsCount(plan.rolloverCapCups),
              ),
              if (plan.offersBonus)
                SubscriptionDetailRow(
                  label: S.extraCredit,
                  value: Formatters.amount(plan.bonusValue),
                ),
              SubscriptionDetailRow(
                label: S.renewalLabel,
                value: plan.renewalPolicyLabel,
              ),
              SubscriptionDetailRow(
                label: S.branchLabel,
                value: plan.allBranches ? S.allBranches : S.selectedBranches,
              ),
              SubscriptionDetailRow(
                label: S.productsLabel,
                value: plan.productScopeLabel,
              ),
              if (plan.coversSelectedProducts) ...[
                SizedBox(height: AppSpacing.md),
                Text(S.includedProducts, style: AppFonts.semiBold16(context)),
                SizedBox(height: AppSpacing.xs),
                _IncludedProducts(
                  state: state,
                  currencyCode: plan.currencyCode,
                  onRetry: () => context
                      .read<SubscriptionCubit>()
                      .loadPlanProducts(plan.id),
                ),
              ],
              SizedBox(height: AppSpacing.lg),
              FilledButton(
                // A second tap cannot tell whether the first created a
                // subscription, and paying twice is the worse answer.
                onPressed: state.isMutating ? null : () => _subscribe(context),
                child: Text(S.subscribeNow),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The products a "selected products" plan covers.
///
/// A read that has not come back yet and one that found nothing are shown
/// apart, so an empty list never looks like a spinner that never stops.
class _IncludedProducts extends StatelessWidget {
  const _IncludedProducts({
    required this.state,
    required this.currencyCode,
    required this.onRetry,
  });

  final SubscriptionState state;
  final String currencyCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.planProductsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.couldNotLoadPlanProducts, style: AppFonts.regular14(context)),
          TextButton(onPressed: onRetry, child: Text(S.retry)),
        ],
      );
    }
    final products = state.planProducts;
    if (products == null) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (products.isEmpty) return Text(S.noProductsYet);
    return Column(
      children: [
        for (final product in products)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: AppSizes.px40,
              height: AppSizes.px40,
              child: DbImage(image: product.imageUrl),
            ),
            title: Text(product.name),
            subtitle: Text(Formatters.price(product.price, currencyCode)),
          ),
      ],
    );
  }
}
