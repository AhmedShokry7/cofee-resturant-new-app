import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_detail_row.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_image.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SubscriptionPlanDetailsPage extends StatelessWidget {
  const SubscriptionPlanDetailsPage({super.key, required this.plan});

  final SubscriptionPlan plan;

  static const routeName = '/subscription-plan-details';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SubscriptionCubit(repository: context.read<SubscriptionRepository>())
            ..loadPlanProducts(plan.id),
      child: _PlanDetailsView(plan: plan),
    );
  }
}

class _PlanDetailsView extends StatelessWidget {
  const _PlanDetailsView({required this.plan});

  final SubscriptionPlan plan;

  Future<void> _subscribe(BuildContext context) async {
    final cubit = context.read<SubscriptionCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await cubit.subscribe(plan);
    final subscription = cubit.state.subscription;
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
                value: '${plan.durationDays}',
              ),
              SubscriptionDetailRow(
                label: S.cupsPerCycle,
                value: '${plan.cupsPerCycle}',
              ),
              SubscriptionDetailRow(
                label: S.rolloverCap,
                value: '${plan.rolloverCapCups}',
              ),
              if (plan.bonusType != 'none')
                SubscriptionDetailRow(
                  label: S.extraCredit,
                  value: Formatters.amount(plan.bonusValue),
                ),
              SubscriptionDetailRow(
                label: S.renewalLabel,
                value: plan.renewalPolicy == 'auto'
                    ? S.renewalAutomatic
                    : S.renewalManual,
              ),
              SubscriptionDetailRow(
                label: S.branchLabel,
                value: plan.allBranches ? S.allBranches : S.selectedBranches,
              ),
              SubscriptionDetailRow(
                label: S.productsLabel,
                value: plan.productScope == 'all'
                    ? S.allProducts
                    : S.selectedProducts,
              ),
              if (plan.productScope == 'selected') ...[
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
                onPressed: state.loading ? null : () => _subscribe(context),
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
            leading: _ProductImage(product: product),
            title: Text(product.name),
            subtitle: Text(Formatters.price(product.price, currencyCode)),
          ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});

  final SubscriptionPlanProduct product;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty)
      return const SizedBox(width: AppSizes.px40, height: AppSizes.px40);
    if (url.startsWith('assets/')) {
      return Image.asset(url, width: 40, height: 40, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
    );
  }
}
