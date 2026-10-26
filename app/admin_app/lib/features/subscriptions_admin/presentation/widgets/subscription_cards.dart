import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_avatar.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_format.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

class SubscriptionCards extends StatelessWidget {
  const SubscriptionCards({
    super.key,
    required this.subscriptions,
    required this.onOpen,
  });

  final List<AdminSubscription> subscriptions;
  final ValueChanged<AdminSubscription> onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: subscriptions.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final subscription = subscriptions[index];
      return _SubscriptionCard(
        subscription: subscription,
        onOpen: () => onOpen(subscription),
      );
    },
  );
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription, required this.onOpen});

  final AdminSubscription subscription;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final subtle = dark ? AppColor.darkTextSecondary : AppColor.adminSubtle;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final status = SubscriptionStatusView.of(subscription);
    final contact = subscriptionContactLine(subscription);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onOpen,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: dark ? AppColor.darkBorder : AppColor.adminCardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SubscriptionAvatar(subscription: subscription, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscriptionCustomerName(subscription),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        if (contact != null)
                          Text(
                            contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtle,
                              fontSize: AppFontSizes.size10,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AdminStatusBadge(label: status.label, color: status.color),
                  const SizedBox(width: 4),
                  HugeIcon(
                    icon: rtl
                        ? HugeIcons.strokeRoundedArrowLeft01
                        : HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: AppColor.adminMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscriptionPlanName(subscription),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size11_5,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        Text(
                          subscriptionPrice(subscription),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dark
                                ? AppColor.darkTextSecondary
                                : AppColor.adminMuted,
                            fontSize: AppFontSizes.size10,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    subscriptionCupsValue(subscription),
                    style: TextStyle(
                      color: body,
                      fontSize: AppFontSizes.size10_5,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: subscription.cupsProgress,
                  minHeight: 5,
                  color: subscription.isActive
                      ? AppColor.adminAccent
                      : AppColor.adminMuted,
                  backgroundColor: dark
                      ? AppColor.darkSurfaceContainer
                      : AppColor.adminAccentSurface,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.subscriptionsColumnPeriod,
                      child: Text(
                        subscription.endsAt == null
                            ? S.subscriptionsNotStartedYet
                            : subscriptionDate(subscription.endsAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? AppColor.darkTextSecondary
                              : AppColor.adminDate,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.subscriptionsColumnLastUsed,
                      child: Text(
                        subscriptionLastUsed(subscription),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? AppColor.darkTextSecondary
                              : AppColor.adminDate,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.subscriptionsColumnAutoRenew,
                      child: Text(
                        subscriptionAutoRenewValue(subscription),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: body,
                          fontSize: AppFontSizes.size10_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
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
