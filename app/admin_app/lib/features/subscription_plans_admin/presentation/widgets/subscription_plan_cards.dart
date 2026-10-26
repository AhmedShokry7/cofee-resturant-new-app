import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/plan_format.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class SubscriptionPlanCards extends StatelessWidget {
  const SubscriptionPlanCards({
    super.key,
    required this.plans,
    required this.onEdit,
  });

  final List<AdminSubscriptionPlan> plans;
  final ValueChanged<AdminSubscriptionPlan> onEdit;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: plans.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final plan = plans[index];
      return _PlanCard(plan: plan, onTap: () => onEdit(plan));
    },
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final AdminSubscriptionPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final radius = BorderRadius.circular(12);
    final body = adminBodyColor(theme);
    final muted = adminMutedColor(theme);
    final subtle = adminSubtleColor(theme);
    final status = SubscriptionPlanStatusView.of(plan);
    final description = subscriptionPlanDescription(plan);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminTintedSurfaceColor(theme),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedPackage,
                      size: 18,
                      color: dark
                          ? AppColor.darkTextSecondary
                          : AppColor.adminMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscriptionPlanName(plan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        Text(
                          description ?? subscriptionPlanCode(plan),
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
                  const SizedBox(width: 2),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit01,
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
                          subscriptionPlanPrice(plan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: body,
                            fontSize: AppFontSizes.size15,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_3,
                          ),
                        ),
                        Text(
                          subscriptionPlanDuration(plan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted,
                            fontSize: AppFontSizes.size10,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      subscriptionPlanSubscribers(plan),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppFontSizes.size10,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.subscriptionPlansColumnCups,
                      child: Text(
                        subscriptionPlanCups(plan),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: body,
                          fontSize: AppFontSizes.size10_5,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.subscriptionPlansColumnBonus,
                      child: Text(
                        subscriptionPlanBonus(plan),
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
                  Expanded(
                    child: AdminLabeledValue(
                      label: S.subscriptionPlansColumnRenewal,
                      child: Text(
                        subscriptionPlanRenewal(plan),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    size: 13,
                    color: muted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      subscriptionPlanBranchesScope(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedPackage,
                    size: 13,
                    color: muted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      subscriptionPlanProductsScope(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
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
