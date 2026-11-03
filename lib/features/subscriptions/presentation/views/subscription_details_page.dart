import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/data/tap_checkout_config.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_detail_row.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SubscriptionDetailsPage extends StatelessWidget {
  const SubscriptionDetailsPage({super.key});

  static const routeName = '/subscription-details';

  @override
  Widget build(BuildContext context) {
    // `my_subscription` is revoked from anon (074), so a guest cannot read a
    // subscription that does not exist yet. The shared prompt replaces the
    // request.
    return AuthGuard(
      child: BlocProvider(
        create: (context) => SubscriptionCubit(
          repository: context.read<SubscriptionRepository>(),
        )..load(),
        child: const _SubscriptionDetailsView(),
      ),
    );
  }
}

class _SubscriptionDetailsView extends StatelessWidget {
  const _SubscriptionDetailsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.mySubscription)),
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
                  Text(S.couldNotLoadSubscription),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.read<SubscriptionCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              ),
            );
          }
          final subscription = state.subscription;
          if (subscription == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.noSubscriptionYet),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(SubscriptionPlansPage.routeName),
                    child: Text(S.browsePlans),
                  ),
                ],
              ),
            );
          }
          return _SubscriptionBody(
            subscription: subscription,
            state: state,
            cubit: context.read<SubscriptionCubit>(),
          );
        },
      ),
    );
  }
}

class _SubscriptionBody extends StatelessWidget {
  const _SubscriptionBody({
    required this.subscription,
    required this.state,
    required this.cubit,
  });

  final CustomerSubscription subscription;
  final SubscriptionState state;
  final SubscriptionCubit cubit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(subscription.planName, style: AppFonts.semiBold20(context)),
        SizedBox(height: AppSpacing.sm),
        SubscriptionDetailRow(
          label: S.subscriptionStatus,
          value: subscription.statusLabel,
        ),
        if (subscription.startsAt != null)
          SubscriptionDetailRow(
            label: S.subscriptionStart,
            value: Formatters.date(subscription.startsAt!),
          ),
        if (subscription.endsAt != null)
          SubscriptionDetailRow(
            label: S.subscriptionEnd,
            value: Formatters.date(subscription.endsAt!),
          ),
        SubscriptionDetailRow(
          label: S.availableCups,
          value: '${subscription.availableCups}',
        ),
        SubscriptionDetailRow(
          label: S.cupsUsed,
          value: '${subscription.cupsUsed}',
        ),
        SubscriptionDetailRow(
          label: S.cupsCarriedOver,
          value: '${subscription.cupsCarriedOver}',
        ),
        SubscriptionDetailRow(
          label: S.extraCredit,
          value: Formatters.amount(subscription.bonusBalance),
        ),
        if (subscription.bonusExpiresAt != null)
          SubscriptionDetailRow(
            label: S.creditExpires,
            value: Formatters.date(subscription.bonusExpiresAt!),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(S.autoRenew),
          value: subscription.autoRenew,
          onChanged: subscription.isActive
              ? (value) => cubit.setAutoRenew(value)
              : null,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (subscription.isPendingPayment)
              FilledButton(
                onPressed: () => cubit.load(),
                child: Text(S.checkPaymentStatus),
              ),
            if (subscription.isActive)
              FilledButton(
                onPressed: () => cubit.showQr(),
                child: Text(S.showQrCode),
              ),
            OutlinedButton(
              onPressed: () => _renew(context),
              child: Text(S.renew),
            ),
            OutlinedButton(
              onPressed: subscription.isActive ? () => _cancel(context) : null,
              child: Text(S.cancel),
            ),
          ],
        ),
        if (state.qrToken != null) ...[
          SizedBox(height: AppSpacing.md),
          Text(S.qrSingleUseHint, style: AppFonts.regular14(context)),
          SizedBox(height: AppSpacing.xs),
          SelectableText(state.qrToken!),
        ],
        SizedBox(height: AppSpacing.lg),
        Text(S.usageHistory, style: AppFonts.semiBold16(context)),
        SizedBox(height: AppSpacing.xs),
        _UsageHistory(
          state: state,
          onRetry: () => cubit.loadUsage(subscription.id),
        ),
      ],
    );
  }

  /// A renewal is a new subscription, so the page tells one apart from a
  /// failure by the id it ends up with.
  Future<void> _renew(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await cubit.renew();
    final renewed = cubit.state.subscription;
    if (renewed == null || renewed.id == subscription.id) {
      if (cubit.state.error != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(S.couldNotRenewSubscription)),
        );
      }
      return;
    }
    if (!context.mounted) return;
    CardPaymentPage.pushForSubscription(
      context,
      subscriptionId: renewed.id,
      amount: cubit.renewalPlan?.price ?? 0,
      currency:
          cubit.renewalPlan?.currencyCode ?? TapCheckoutConfig.defaultCurrency,
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await cubit.cancel();
    if (cubit.state.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(S.couldNotCancelSubscription)),
      );
    }
  }
}

/// The cups already spent.
///
/// "Not read yet" and "read, nothing there" are shown apart, so an empty
/// history never looks like a spinner that never stops.
class _UsageHistory extends StatelessWidget {
  const _UsageHistory({required this.state, required this.onRetry});

  final SubscriptionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.usageError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.couldNotLoadUsage, style: AppFonts.regular14(context)),
          TextButton(onPressed: onRetry, child: Text(S.retry)),
        ],
      );
    }
    final usage = state.usage;
    if (usage == null) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (usage.isEmpty) return Text(S.noUsageYet);
    return Column(
      children: [
        for (final entry in usage)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.productName ?? entry.method),
            subtitle: Text('${entry.quantity} ${S.cupUnit}'),
          ),
      ],
    );
  }
}
