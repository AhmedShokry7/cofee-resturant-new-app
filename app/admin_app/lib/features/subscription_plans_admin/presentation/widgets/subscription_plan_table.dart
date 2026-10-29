import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/plan_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class SubscriptionPlanTable extends StatelessWidget {
  const SubscriptionPlanTable({
    super.key,
    required this.plans,
    required this.onEdit,
  });

  final List<AdminSubscriptionPlan> plans;
  final ValueChanged<AdminSubscriptionPlan> onEdit;

  static const _actionWidth = 40.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 1160), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final plan in plans)
                  _Row(plan: plan, onTap: () => onEdit(plan)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: _cell(S.subscriptionPlansColumnPlan, dark)),
          Expanded(flex: 2, child: _cell(S.status, dark)),
          Expanded(flex: 2, child: _cell(S.subscriptionPlansColumnPrice, dark)),
          Expanded(
            flex: 2,
            child: _cell(S.subscriptionPlansColumnDuration, dark),
          ),
          Expanded(flex: 2, child: _cell(S.subscriptionPlansColumnCups, dark)),
          Expanded(
            flex: 2,
            child: _cell(S.subscriptionPlansColumnProducts, dark),
          ),
          Expanded(flex: 3, child: _cell(S.subscriptionPlansColumnBonus, dark)),
          Expanded(
            flex: 2,
            child: _cell(S.subscriptionPlansColumnRenewal, dark),
          ),
          Expanded(
            flex: 3,
            child: _cell(S.subscriptionPlansColumnSubscribers, dark),
          ),
          const SizedBox(width: SubscriptionPlanTable._actionWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, bool dark) => Text(
    label,
    textAlign: TextAlign.start,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.plan, required this.onTap});

  final AdminSubscriptionPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final body = adminBodyColor(theme);
    final muted = adminMutedColor(theme);
    final status = SubscriptionPlanStatusView.of(plan);
    final description = subscriptionPlanDescription(plan);

    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: adminTintedSurfaceColor(theme),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: AppIcon(
                        AppIcons.package,
                        size: 16,
                        color: dark
                            ? AppColor.darkTextSecondary
                            : AppColor.adminMuted,
                      ),
                    ),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscriptionPlanName(plan),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            description ?? subscriptionPlanCode(plan),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontSize: AppFontSizes.size9,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AdminStatusBadge(
                      label: status.label,
                      color: status.color,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _TextCell(
                  value: subscriptionPlanPrice(plan),
                  color: body,
                  weight: AppFontWeights.semiBold,
                  isMoney: true,
                ),
              ),
              Expanded(
                flex: 2,
                child: _TextCell(
                  value: subscriptionPlanDuration(plan),
                  color: muted,
                ),
              ),
              Expanded(
                flex: 2,
                child: _TextCell(
                  value: subscriptionPlanCups(plan),
                  color: body,
                ),
              ),
              Expanded(
                flex: 2,
                child: _TextCell(
                  value: subscriptionPlanProductsScope(plan),
                  color: muted,
                ),
              ),
              Expanded(
                flex: 3,
                child: _TwoLineCell(
                  primary: subscriptionPlanBonus(plan),
                  secondary: subscriptionPlanBonusTypeLabel(plan.bonusType),
                  primaryColor: body,
                  secondaryColor: muted,
                  primaryIsMoney: subscriptionPlanBonusIsMoney(plan),
                ),
              ),
              Expanded(
                flex: 2,
                child: _TextCell(
                  value: subscriptionPlanRenewal(plan),
                  color: body,
                ),
              ),
              Expanded(
                flex: 3,
                child: _TwoLineCell(
                  primary: subscriptionPlanSubscribersTotal(plan),
                  secondary: subscriptionPlanSubscribersActive(plan),
                  primaryColor: body,
                  secondaryColor: muted,
                ),
              ),
              SizedBox(
                width: SubscriptionPlanTable._actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Tooltip(
                    message: S.subscriptionPlanEditAction,
                    child: AppIcon(
                      AppIcons.edit01,
                      size: 16,
                      color: AppColor.adminMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({
    required this.value,
    required this.color,
    this.weight,
    this.isMoney = false,
  });

  final String value;
  final Color color;
  final FontWeight? weight;

  /// True when [value] is an amount, so the currency mark sits beside it.
  final bool isMoney;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: AppFontSizes.size10_5,
        fontWeight: weight ?? AppFontWeights.regular,
        height: AppTextHeights.line1_5,
      ),
    );
    if (!isMoney) return text;
    return Row(
      children: [
        Flexible(child: text),
        const SizedBox(width: AppSizes.px4),
        const CurrencyIcon(size: 12),
      ],
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
    this.primaryIsMoney = false,
  });

  final String primary;
  final String secondary;
  final Color primaryColor;
  final Color secondaryColor;

  /// True when [primary] is an amount, so the currency mark sits beside it.
  final bool primaryIsMoney;

  @override
  Widget build(BuildContext context) {
    final primaryText = Text(
      primary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: primaryColor,
        fontSize: AppFontSizes.size10_5,
        fontWeight: AppFontWeights.semiBold,
        height: AppTextHeights.line1_5,
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primaryIsMoney)
          Row(
            children: [
              Flexible(child: primaryText),
              const SizedBox(width: AppSizes.px4),
              const CurrencyIcon(size: 12),
            ],
          )
        else
          primaryText,
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: secondaryColor,
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}
