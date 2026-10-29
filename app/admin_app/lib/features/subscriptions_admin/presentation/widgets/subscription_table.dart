import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_avatar.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class SubscriptionTable extends StatelessWidget {
  const SubscriptionTable({
    super.key,
    required this.subscriptions,
    required this.onOpen,
  });

  final List<AdminSubscription> subscriptions;
  final ValueChanged<AdminSubscription> onOpen;

  static const _actionWidth = 40.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 1120), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final subscription in subscriptions)
                  _Row(
                    subscription: subscription,
                    onTap: () => onOpen(subscription),
                  ),
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
          Expanded(flex: 4, child: _cell(S.subscriptionsColumnCustomer, dark)),
          Expanded(flex: 3, child: _cell(S.subscriptionsColumnPlan, dark)),
          Expanded(flex: 3, child: _cell(S.status, dark)),
          Expanded(flex: 3, child: _cell(S.subscriptionsColumnCups, dark)),
          Expanded(flex: 3, child: _cell(S.subscriptionsColumnPeriod, dark)),
          Expanded(flex: 2, child: _cell(S.subscriptionsColumnLastUsed, dark)),
          Expanded(flex: 2, child: _cell(S.subscriptionsColumnAutoRenew, dark)),
          const SizedBox(width: SubscriptionTable._actionWidth),
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
  const _Row({required this.subscription, required this.onTap});

  final AdminSubscription subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    final subtle = dark ? AppColor.darkTextSecondary : AppColor.adminSubtle;
    final date = dark ? AppColor.darkTextSecondary : AppColor.adminDate;
    final status = SubscriptionStatusView.of(subscription);
    final contact = subscriptionContactLine(subscription);
    final price = subscriptionPrice(subscription);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    SubscriptionAvatar(subscription: subscription),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscriptionCustomerName(subscription),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11,
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
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscriptionPlanName(subscription),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: body,
                        fontSize: AppFontSizes.size11,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            price ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dark
                                  ? AppColor.darkTextSecondary
                                  : AppColor.adminMuted,
                              fontSize: AppFontSizes.size9,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                        ),
                        if (price != null) ...[
                          const SizedBox(width: AppSizes.px4),
                          const CurrencyIcon(size: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
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
              Expanded(flex: 3, child: _CupsCell(subscription: subscription)),
              Expanded(
                flex: 3,
                child: _PeriodCell(
                  subscription: subscription,
                  bodyColor: body,
                  dateColor: date,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  subscriptionLastUsed(subscription),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: date,
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
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
              SizedBox(
                width: SubscriptionTable._actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Tooltip(
                    message: S.subscriptionsViewAction,
                    child: AppIcon(
                      rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
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

class _CupsCell extends StatelessWidget {
  const _CupsCell({required this.subscription});

  final AdminSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = dark ? AppColor.darkText : AppColor.adminBody;
    return Row(
      children: [
        SizedBox(
          width: AppSizes.px42,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: subscription.cupsProgress,
              minHeight: 4,
              color: subscription.isActive
                  ? AppColor.adminAccent
                  : AppColor.adminMuted,
              backgroundColor: dark
                  ? AppColor.darkSurfaceContainer
                  : AppColor.adminAccentSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.px8),
        Flexible(
          child: Text(
            subscriptionCupsValue(subscription),
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
      ],
    );
  }
}

class _PeriodCell extends StatelessWidget {
  const _PeriodCell({
    required this.subscription,
    required this.bodyColor,
    required this.dateColor,
  });

  final AdminSubscription subscription;
  final Color bodyColor;
  final Color dateColor;

  @override
  Widget build(BuildContext context) {
    final ends = subscription.endsAt;
    final starts = subscription.startsAt;
    final primary = ends == null
        ? S.subscriptionsNotStartedYet
        : '${S.subscriptionEnds}: ${subscriptionDate(ends)}';
    final secondary = ends == null && starts == null
        ? ''
        : subscription.isActive
        ? subscriptionDaysRemaining(subscription)
        : starts == null
        ? S.subscriptionsNotStartedYet
        : '${S.subscriptionStarts}: ${subscriptionDate(starts)}';
    final warn = subscription.isExpiringSoon;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: bodyColor,
            fontSize: AppFontSizes.size10_5,
            height: AppTextHeights.line1_5,
          ),
        ),
        if (secondary.isNotEmpty)
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: warn
                  ? adminFlagForeground(
                      Theme.of(context),
                      AppColor.adminWarning,
                    )
                  : dateColor,
              fontSize: AppFontSizes.size9,
              fontWeight: warn
                  ? AppFontWeights.semiBold
                  : AppFontWeights.regular,
              height: AppTextHeights.line1_5,
            ),
          ),
      ],
    );
  }
}
