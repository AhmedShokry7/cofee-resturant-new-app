import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/payment/data/tap_checkout_config.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';

class SubscriptionDetailsPage extends StatelessWidget {
  const SubscriptionDetailsPage({super.key});

  static const routeName = '/subscription-details';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SubscriptionCubit(
        repository: context.read<SubscriptionRepository>(),
      )..load(),
      child: const _SubscriptionDetailsView(),
    );
  }
}

class _SubscriptionDetailsView extends StatelessWidget {
  const _SubscriptionDetailsView();

  String _t(String ar, String en) => AppLocale.instance.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('\u0627\u0634\u062A\u0631\u0627\u0643\u064A', 'My subscription'))),
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
          final sub = state.subscription;
          if (sub == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t('\u0644\u0627 \u064A\u0648\u062C\u062F \u0627\u0634\u062A\u0631\u0627\u0643 \u062D\u0627\u0644\u064A\u0627\u064B', 'No subscription yet')),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/subscriptions'),
                    child: Text(_t('\u062A\u0635\u0641\u062D \u0627\u0644\u0628\u0627\u0642\u0627\u062A', 'Browse plans')),
                  ),
                ],
              ),
            );
          }
          final isPending = sub.status == 'pending_payment';
          final isActive = sub.status == 'active';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(sub.planName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_t('\u0627\u0644\u062D\u0627\u0644\u0629', 'Status') + ': ' + _statusLabel(sub.status)),
              if (sub.startsAt != null) Text(_t('\u0627\u0644\u0628\u062F\u0627\u064A\u0629', 'Start') + ': ${sub.startsAt}'),
              if (sub.endsAt != null) Text(_t('\u0627\u0644\u0627\u0646\u062A\u0647\u0627\u0621', 'End') + ': ${sub.endsAt}'),
              Text(_t('\u0627\u0644\u0623\u0643\u0648\u0627\u0628 \u0627\u0644\u0645\u062A\u0627\u062D\u0629', 'Available cups') + ': ${sub.availableCups}'),
              Text(_t('\u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645', 'Used') + ': ${sub.cupsUsed}'),
              Text(_t('\u0627\u0644\u0645\u0631\u062D\u0644', 'Carried over') + ': ${sub.cupsCarriedOver}'),
              Text(_t('\u0627\u0644\u0631\u0635\u064A\u062F \u0627\u0644\u0625\u0636\u0627\u0641\u064A', 'Extra credit') + ': ${sub.bonusBalance}'),
              if (sub.bonusExpiresAt != null)
                Text(_t('\u0627\u0646\u062A\u0647\u0627\u0621 \u0627\u0644\u0631\u0635\u064A\u062F', 'Credit expires') + ': ${sub.bonusExpiresAt}'),
              SwitchListTile(
                title: Text(_t('\u062A\u062C\u062F\u064A\u062F \u062A\u0644\u0642\u0627\u0626\u064A', 'Auto renew')),
                value: sub.autoRenew,
                onChanged: isActive
                    ? (value) => context.read<SubscriptionCubit>().setAutoRenew(value)
                    : null,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isPending)
                    FilledButton(
                      onPressed: () => context.read<SubscriptionCubit>().load(),
                      child: Text(_t('\u0627\u0644\u062A\u062D\u0642\u0642 \u0645\u0646 \u062D\u0627\u0644\u0629 \u0627\u0644\u062F\u0641\u0639', 'Check payment status')),
                    ),
                  if (isActive)
                    FilledButton(
                      onPressed: () => context.read<SubscriptionCubit>().showQr(),
                      child: Text(_t('\u0639\u0631\u0636 \u0631\u0645\u0632 QR', 'Show QR code')),
                    ),
                  OutlinedButton(
                    onPressed: () async {
                      final cubit = context.read<SubscriptionCubit>();
                      await cubit.renew();
                      if (!context.mounted) return;
                      final renewed = cubit.state.subscription;
                      if (renewed != null && renewed.id != sub.id) {
                        CardPaymentPage.pushForSubscription(
                          context,
                          subscriptionId: renewed.id,
                          amount: cubit.renewalPlan?.price ?? 0,
                          currency:
                              cubit.renewalPlan?.currencyCode ??
                              TapCheckoutConfig.defaultCurrency,
                        );
                      }
                    },
                    child: Text(_t('\u062A\u062C\u062F\u064A\u062F', 'Renew')),
                  ),
                  OutlinedButton(
                    onPressed: isActive
                        ? () => context.read<SubscriptionCubit>().cancel()
                        : null,
                    child: Text(_t('\u0625\u0644\u063A\u0627\u0621', 'Cancel')),
                  ),
                ],
              ),
              if (state.qrToken != null) ...[
                const SizedBox(height: 12),
                Text(_t('\u0631\u0645\u0632 QR (\u0635\u0627\u0644\u062D 5 \u062F\u0642\u0627\u0626\u0642\u060C \u0644\u0645\u0631\u0629 \u0648\u0627\u062D\u062F\u0629):', 'QR code (valid 5 minutes, single use):')),
                SelectableText(state.qrToken!),
              ],
              const SizedBox(height: 16),
              Text(_t('\u0633\u062C\u0644 \u0627\u0644\u0627\u0633\u062A\u062E\u062F\u0627\u0645', 'Usage history'), style: const TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<SubscriptionUsage>>(
                future: context.read<SubscriptionRepository>().usageHistory(subscriptionId: sub.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) return Text(_t('\u0644\u0627 \u062A\u0648\u062C\u062F \u0639\u0645\u0644\u064A\u0627\u062A', 'No usage yet'));
                  return Column(
                    children: [
                      for (final item in items)
                        ListTile(
                          title: Text(item.method),
                          subtitle: Text('${item.quantity} ' + _t('\u0643\u0648\u0628', 'cup')),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_payment':
        return _t('\u0628\u0627\u0646\u062A\u0638\u0627\u0631 \u062A\u0623\u0643\u064A\u062F \u0627\u0644\u062F\u0641\u0639', 'Pending payment');
      case 'active':
        return _t('\u0641\u0639\u0627\u0644', 'Active');
      case 'expired':
        return _t('\u0645\u0646\u062A\u0647\u064A', 'Expired');
      case 'cancelled':
        return _t('\u0645\u0644\u063A\u064A', 'Cancelled');
      default:
        return status;
    }
  }
}
