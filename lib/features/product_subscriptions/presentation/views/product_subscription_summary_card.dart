import 'package:material_ui/material_ui.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class ProductSubscriptionSummaryCard extends StatelessWidget {
  const ProductSubscriptionSummaryCard({
    super.key,
    required this.subscription,
    required this.onOpen,
  });
  final ProductSubscription subscription;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final item = subscription;
    final ar = AppLocale.instance.isArabic;
    final status = item.status == 'active'
        ? S.activeStatus
        : item.status == 'paused'
        ? S.paused
        : item.status;
    final names = item.items
        .map(
          (p) =>
              '${(ar ? p.productNameAr : p.productNameEn) ?? p.productNameAr ?? p.productNameEn ?? S.product} × ${p.quantity}',
        )
        .join('، ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.autorenew),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.name?.trim().isNotEmpty == true
                          ? item.name!
                          : S.productSubscriptions,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(status, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(names, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(S.repeatInterval(item.intervalValue, item.frequency)),
              if (item.pendingRuns.isNotEmpty)
                Text(
                  S.productSubscriptionReadyLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (item.nextRunAt != null)
                Text(
                  '${S.nextRun}: ${Formatters.date(item.nextRunAt!.toLocal())}',
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      S.subscriptionDetailsAction,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
