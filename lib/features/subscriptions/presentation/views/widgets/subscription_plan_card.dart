import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// Plan card used by the subscription plans grid.
///
/// The picture takes the free space of the card ([Expanded]), so it grows with
/// the cell instead of sitting in a fixed band, while the name, price, cups
/// and the subscribe button keep their fixed slots on a single line.
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    required this.onSubscribe,
  });

  final SubscriptionPlan plan;

  /// Opens the plan details.
  final VoidCallback onTap;

  /// Starts the subscription.
  final VoidCallback onSubscribe;

  String _t(String ar, String en) => AppLocale.instance.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final title = plan.nameAr.isNotEmpty && AppLocale.instance.isArabic
        ? plan.nameAr
        : plan.nameEn;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.expand(
                    child: DbImage(image: plan.imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${_t('السعر', 'Price')}: ${plan.price} ${plan.currencyCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_t('الأكواب', 'Cups')}: ${plan.cupsPerCycle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSubscribe,
                  child: Text(_t('اشترك الآن', 'Subscribe now')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
