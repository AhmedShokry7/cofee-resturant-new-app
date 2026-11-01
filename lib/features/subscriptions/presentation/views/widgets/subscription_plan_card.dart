import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(SpacingTokens.md.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    LayoutTokens.cardRadius.r,
                  ),
                  child: SizedBox.expand(
                    child: DbImage(image: plan.imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
              SizedBox(height: SpacingTokens.sm.h),
              Text(
                plan.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: SpacingTokens.xs.h),
              Text(
                '${S.priceLabel}: ${Formatters.price(plan.price, plan.currencyCode)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${S.cupsLabel}: ${plan.cupsPerCycle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: SpacingTokens.sm.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSubscribe,
                  child: Text(S.subscribeNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
