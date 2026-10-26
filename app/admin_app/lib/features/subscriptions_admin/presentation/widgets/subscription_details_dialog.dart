import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_cubit.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_avatar.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_format.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Future<void> showSubscriptionDetailsDialog({
  required BuildContext context,
  required AdminSubscription subscription,
  required AdminSubscriptionCubit cubit,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        SubscriptionDetailsDialog(subscription: subscription, cubit: cubit),
  );
}

class SubscriptionDetailsDialog extends StatefulWidget {
  const SubscriptionDetailsDialog({
    super.key,
    required this.subscription,
    required this.cubit,
  });

  final AdminSubscription subscription;
  final AdminSubscriptionCubit cubit;

  @override
  State<SubscriptionDetailsDialog> createState() =>
      _SubscriptionDetailsDialogState();
}

class _SubscriptionDetailsDialogState extends State<SubscriptionDetailsDialog> {
  List<AdminSubscriptionUsage> _usage = const <AdminSubscriptionUsage>[];
  bool _loadingUsage = true;
  String? _usageError;
  bool _cancelling = false;

  AdminSubscription get _subscription => widget.subscription;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    setState(() {
      _loadingUsage = true;
      _usageError = null;
    });
    try {
      final usage = await widget.cubit.loadUsage(_subscription.id);
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _loadingUsage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUsage = false;
        _usageError = S.subscriptionsUsageLoadFailed;
      });
    }
  }

  Future<void> _confirmCancel() async {
    if (!_subscription.isCancellable || _cancelling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const AppIcon(
          AppIcons.alert,
          size: 26,
          color: AppColor.errorColor,
        ),
        title: Text(S.subscriptionsCancelTitle),
        content: Text(
          _subscription.isPendingPayment
              ? S.subscriptionsCancelPendingMessage
              : S.subscriptionsCancelMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.subscriptionsCancelKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.errorColor,
              foregroundColor: AppColor.whiteColor,
            ),
            child: Text(S.subscriptionsCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final outcome = await widget.cubit.cancelSubscription(_subscription.id);
    if (!mounted) return;
    setState(() => _cancelling = false);

    switch (outcome) {
      case SubscriptionCancelOutcome.cancelled:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(S.subscriptionsCancelledSuccess)),
        );
        break;
      case SubscriptionCancelOutcome.notFound:
        _showMessage(S.subscriptionsCancelNotFound);
        break;
      case SubscriptionCancelOutcome.notCancellable:
        _showMessage(S.subscriptionsCancelNotAllowed);
        break;
      case SubscriptionCancelOutcome.reservedCups:
        _showMessage(S.subscriptionsCancelReserved);
        break;
      case SubscriptionCancelOutcome.failed:
        _showMessage(S.subscriptionsCancelFailed);
        break;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final narrow =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogPadding;
    final status = SubscriptionStatusView.of(_subscription);
    final canCancel = _subscription.isActive || _subscription.isPendingPayment;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AppSpacing.md : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              onClose: _cancelling ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CustomerPanel(subscription: _subscription, status: status),
                    const SizedBox(height: AppSpacing.md),
                    _StatTiles(subscription: _subscription),
                    const SizedBox(height: AppSpacing.lg),
                    _CupsSection(subscription: _subscription),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final plan = _PlanSection(subscription: _subscription);
                        final period = _PeriodSection(
                          subscription: _subscription,
                        );
                        if (constraints.maxWidth < 620) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              plan,
                              const SizedBox(height: AppSpacing.md),
                              period,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: plan),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: period),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _UsageSection(
                      subscription: _subscription,
                      usage: _usage,
                      loading: _loadingUsage,
                      error: _usageError,
                      onRetry: _loadUsage,
                    ),
                  ],
                ),
              ),
            ),
            _DialogFooter(
              cancelling: _cancelling,
              canCancel: canCancel,
              cancelEnabled: _subscription.isCancellable,
              onCancel: _confirmCancel,
              onClose: () => Navigator.of(context).pop(),
              dark: dark,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.subscriptionsDetailsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size16,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          IconButton(
            tooltip: S.close,
            onPressed: onClose,
            style: IconButton.styleFrom(
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.cancel01,
              size: 18,
              color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPanel extends StatelessWidget {
  const _CustomerPanel({required this.subscription, required this.status});

  final AdminSubscription subscription;
  final SubscriptionStatusView status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contact = subscriptionContactLine(subscription);
    final plan = subscriptionPlanName(subscription);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        children: [
          SubscriptionAvatar(subscription: subscription, size: 46),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscriptionCustomerName(subscription),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size15,
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
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size10_5,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                Text(
                  plan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AdminStatusBadge(label: status.label, color: status.color),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.subscription});

  final AdminSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      AdminStatTile(
        icon: AppIcons.coffee02,
        tint: AppColor.adminWarning,
        surface: AppColor.adminWarningSurface,
        label: S.subscriptionsCupsRemaining,
        value: subscriptionCupsRemaining(subscription),
      ),
      AdminStatTile(
        icon: AppIcons.time01,
        tint: AppColor.adminInfo,
        surface: AppColor.adminInfoSurface,
        label: S.subscriptionsDaysRemainingLabel,
        value: subscriptionDaysRemaining(subscription),
      ),
      AdminStatTile(
        icon: AppIcons.repeat,
        tint: AppColor.tintVioletInk,
        surface: AppColor.tintVioletSurface,
        label: S.subscriptionsUsageRedemptions,
        value: subscriptionCount(subscription.usageCount),
      ),
      AdminStatTile(
        icon: AppIcons.clock01,
        tint: AppColor.trendPositive,
        surface: AppColor.tintGreenSurface,
        label: S.subscriptionsColumnLastUsed,
        value: subscriptionLastUsed(subscription),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 4;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _CupsSection extends StatelessWidget {
  const _CupsSection({required this.subscription});

  final AdminSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = subscription.cupsProgress;
    final percent = localizeDigits('${(progress * 100).round()}%');
    final remaining = subscription.cupsAvailable;
    final progressColor = subscription.isActive
        ? (remaining <= 0
              ? AppColor.errorColor
              : progress >= .8
              ? AppColor.adminWarning
              : AppColor.adminAccent)
        : AppColor.adminMuted;

    final facts = <(String, String)>[
      (
        S.subscriptionsCupsEntitled,
        subscriptionCount(subscription.cupsEntitled),
      ),
      (
        S.subscriptionsCupsCarried,
        subscriptionCount(subscription.cupsCarriedOver),
      ),
      (S.subscriptionsCupsUsed, subscriptionCount(subscription.cupsUsed)),
      (
        S.subscriptionsCupsReserved,
        subscriptionCount(subscription.cupsReserved),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${subscriptionCupsRemaining(subscription)} / '
                      '${subscriptionCount(subscription.cupsTotal)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size22,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_3,
                      ),
                    ),
                    Text(
                      S.subscriptionsCupsRemaining,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    percent,
                    style: TextStyle(
                      color: progressColor,
                      fontSize: AppFontSizes.size12,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  Text(
                    S.subscriptionsCupsUsed,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: progressColor,
              backgroundColor: adminTintedSurfaceColor(theme),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 520 ? 2 : 4;
              const spacing = 8.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final fact in facts)
                    SizedBox(
                      width: width,
                      child: _Fact(label: fact.$1, value: fact.$2),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_5,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size12,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.subscription});

  final AdminSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final code = subscription.planCode?.trim() ?? '';
    return AdminSectionCard(
      title: S.subscriptionsPlanSection,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: S.subscriptionsColumnPlan,
            value: subscriptionPlanName(subscription),
          ),
          _InfoRow(
            label: S.subscriptionsPlanCode,
            value: code.isEmpty ? '—' : code,
          ),
          _InfoRow(
            label: S.subscriptionsPlanPrice,
            value: subscriptionPrice(subscription),
          ),
          _InfoRow(
            label: S.subscriptionsPlanDurationLabel,
            value: subscriptionDuration(subscription),
          ),
          _InfoRow(
            label: S.subscriptionsAutoRenew,
            value: subscriptionAutoRenewValue(subscription),
          ),
          _InfoRow(
            label: S.subscriptionsBonusBalance,
            value: subscriptionBonusBalance(subscription),
          ),
          _InfoRow(
            label: S.subscriptionsBonusUntil,
            value: subscriptionDate(subscription.bonusExpiresAt),
          ),
        ],
      ),
    );
  }
}

class _PeriodSection extends StatelessWidget {
  const _PeriodSection({required this.subscription});

  final AdminSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final reference = subscription.paymentReference?.trim() ?? '';
    return AdminSectionCard(
      title: S.subscriptionsPeriodSection,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: S.subscriptionStarts,
            value: subscription.startsAt == null
                ? S.subscriptionsNotStartedYet
                : subscriptionDate(subscription.startsAt),
          ),
          _InfoRow(
            label: S.subscriptionEnds,
            value: subscription.endsAt == null
                ? S.subscriptionsNotStartedYet
                : subscriptionDate(subscription.endsAt),
          ),
          _InfoRow(
            label: S.subscriptionsDaysRemainingLabel,
            value: subscriptionDaysRemaining(subscription),
          ),
          _InfoRow(
            label: S.subscriptionsPaymentReference,
            value: reference.isEmpty ? '—' : reference,
          ),
          _InfoRow(
            label: S.createdAt,
            value: subscriptionDateTime(subscription.createdAt),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageSection extends StatelessWidget {
  const _UsageSection({
    required this.subscription,
    required this.usage,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final AdminSubscription subscription;
  final List<AdminSubscriptionUsage> usage;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminSectionCard(
      title: S.subscriptionsUsageCountLabel(subscription.usageCount),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : error != null
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size10_5,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: Text(S.tryAgain)),
              ],
            )
          : usage.isEmpty
          ? AdminEmptyState(
              icon: AppIcons.coffee02,
              message: S.subscriptionsNoUsage,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < usage.length; index++) ...[
                  _UsageRow(usage: usage[index]),
                  if (index != usage.length - 1)
                    Divider(height: 13, color: adminRowBorderColor(theme)),
                ],
                if (subscription.usageCount > usage.length)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      S.subscriptionsUsageLimited(
                        usage.length,
                        subscription.usageCount,
                      ),
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.usage});

  final AdminSubscriptionUsage usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final branch = subscriptionUsageBranch(usage);
    final product = subscriptionUsageProduct(usage);
    final order = usage.orderNumber?.trim() ?? '';
    final place = [
      if (product != '—') product,
      if (branch != '—') branch,
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: adminTintedSurfaceColor(theme),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AppIcon(
              AppIcons.coffee02,
              size: 15,
              color: adminMutedColor(theme),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subscriptionUsageMethodLabel(usage.method),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminBodyColor(theme),
                          fontSize: AppFontSizes.size11,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.px6),
                    Text(
                      subscriptionUsageCups(usage),
                      maxLines: 1,
                      style: TextStyle(
                        color: dark ? AppColor.darkText : AppColor.adminAccent,
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
                if (place.isNotEmpty)
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size9_5,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                if (order.isNotEmpty)
                  Text(
                    '${S.orderNumber}: ${localizeDigits(order)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          SizedBox(
            width: 92,
            child: Text(
              subscriptionDateTime(usage.createdAt),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.cancelling,
    required this.canCancel,
    required this.cancelEnabled,
    required this.onCancel,
    required this.onClose,
    required this.dark,
  });

  final bool cancelling;
  final bool canCancel;
  final bool cancelEnabled;
  final VoidCallback onCancel;
  final VoidCallback onClose;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final cancelButton = FilledButton.icon(
      onPressed: cancelling ? null : (cancelEnabled ? onCancel : null),
      style: FilledButton.styleFrom(
        backgroundColor: AppColor.errorColor,
        foregroundColor: AppColor.whiteColor,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      icon: cancelling
          ? const SizedBox(
              width: AppSizes.px14,
              height: AppSizes.px14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColor.whiteColor,
              ),
            )
          : const AppIcon(
              AppIcons.cancel01,
              size: 16,
              color: AppColor.whiteColor,
            ),
      label: Text(
        cancelling ? S.subscriptionsCancelBusy : S.subscriptionsCancelAction,
        style: const TextStyle(
          fontSize: AppFontSizes.size11,
          fontWeight: AppFontWeights.semiBold,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          if (canCancel)
            Tooltip(
              message: cancelEnabled
                  ? S.subscriptionsCancelAction
                  : S.subscriptionsCancelReserved,
              child: cancelButton,
            ),
          const Spacer(),
          TextButton(
            onPressed: cancelling ? null : onClose,
            child: Text(S.close),
          ),
        ],
      ),
    );
  }
}
