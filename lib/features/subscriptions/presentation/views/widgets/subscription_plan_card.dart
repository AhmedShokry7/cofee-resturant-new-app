import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
    this.busy = false,
  });

  final SubscriptionPlan plan;

  /// Opens the plan details.
  final VoidCallback onTap;

  /// Starts the subscription.
  final VoidCallback onSubscribe;

  /// A write started from this card is still in flight.
  ///
  /// Both answers are withheld while it is: a second tap cannot tell whether
  /// the first one created a subscription, and paying twice is the worse of the
  /// two outcomes.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final price = Formatters.price(plan.price, plan.currencyCode);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // The card is one control that opens one page, and the button inside it
      // is a different answer. A reader has to be told which is which, or the
      // whole cell reads as a single tap.
      child: Semantics(
        button: !busy,
        label: '${plan.name}. ${S.priceLabel}: $price',
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.cardRadius,
                    ),
                    child: SizedBox.expand(
                      child: DbImage(image: plan.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.semiBold16(context),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '${S.priceLabel}: $price',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.regular14(context),
                ),
                Text(
                  '${S.cupsLabel}: ${plan.cupsPerCycle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.regular14(context),
                ),
                SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : onSubscribe,
                    child: Text(
                      S.subscribeNow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
