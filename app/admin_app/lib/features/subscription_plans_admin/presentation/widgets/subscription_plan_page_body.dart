import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_metrics.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_directory.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class SubscriptionPlanPageBody extends StatelessWidget {
  const SubscriptionPlanPageBody({
    super.key,
    required this.plans,
    required this.metrics,
    required this.search,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onEdit,
    this.errorMessage,
    this.onRefresh,
  });

  final List<AdminSubscriptionPlan> plans;
  final AdminSubscriptionPlanMetrics metrics;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final ValueChanged<AdminSubscriptionPlan> onEdit;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.subscriptionPlans,
            subtitle: S.subscriptionPlansDescription,
            actions: [
              CustomBtn(
                text: S.subscriptionPlanAddAction,
                onPressed: onAdd,
                leadingIcon: const Icon(AppIcons.add01, size: 18),
                height: 42,
                borderRadius: AppRadius.pill,
                backgroundColor: AppColor.primaryColor,
                textColor: AppColor.whiteColor,
              ),
            ],
          ),
          if (errorMessage != null)
            AdminInlineError(message: errorMessage!, onRetry: onRefresh),
          const SizedBox(height: AppSizes.px8),
          SubscriptionPlanMetricsCards(metrics: metrics),
          const SizedBox(height: AppSizes.px16),
          Expanded(
            child: SubscriptionPlanDirectory(
              plans: plans,
              search: search,
              onSearchChanged: onSearchChanged,
              onEdit: onEdit,
              onAdd: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}
