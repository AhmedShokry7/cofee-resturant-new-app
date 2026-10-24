import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';

class SubscriptionRecords extends StatelessWidget {
  const SubscriptionRecords({
    super.key,
    required this.subscriptions,
    this.search = '',
  });

  /// Every loaded subscription; the list filters them with [search].
  final List<AdminSubscription> subscriptions;

  /// The word the admin is looking for.
  final String search;

  List<AdminSubscription> get _filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return subscriptions;
    return subscriptions
        .where(
          (s) =>
              (s.customerName ?? '').toLowerCase().contains(q) ||
              (s.customerEmail ?? '').toLowerCase().contains(q) ||
              (s.planNameEn ?? '').toLowerCase().contains(q) ||
              (s.planNameAr ?? '').toLowerCase().contains(q) ||
              s.status.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = _filtered;
    if (subscriptions.isEmpty) {
      return Center(
        child: Text(
          'No subscriptions found',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: subscriptions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final sub = subscriptions[index];
        return _SubscriptionCard(subscription: sub);
      },
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final AdminSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;

    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subscription.customerName ?? 'Unknown customer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: subscription.status == 'active'
                      ? AppColor.primaryColor
                      : AppColor.greyColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  subscription.status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.whiteColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            subscription.planNameFor(language),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subscription.planPrice != null)
            Text(
              '${subscription.planPrice!.toStringAsFixed(2)} ${subscription.currencyCode ?? 'SAR'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.primaryColor,
              ),
            ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Cups: ${subscription.cupsUsed}/${subscription.cupsEntitled}  (carried: ${subscription.cupsCarriedOver}, reserved: ${subscription.cupsReserved})',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Starts: ${subscription.startsAt}  Ends: ${subscription.endsAt}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          Text(
            'Auto renew: ${subscription.autoRenew}  •  Bonus: ${subscription.bonusBalance}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
        ],
      ),
    );
  }
}
