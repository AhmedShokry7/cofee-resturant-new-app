import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_money_bits.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class LoyaltyRewardGrid extends StatelessWidget {
  const LoyaltyRewardGrid({
    super.key,
    required this.rewards,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminLoyaltyReward> rewards;
  final bool canManage;
  final ValueChanged<AdminLoyaltyReward> onEdit;
  final ValueChanged<AdminLoyaltyReward> onToggle;
  final ValueChanged<AdminLoyaltyReward> onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Coupon catalogue: five cards across on wide screens, never below one.
      final columns = width >= 1160
          ? 5
          : width >= 920
          ? 4
          : width >= 680
          ? 3
          : width >= 460
          ? 2
          : 1;
      return GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 176,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: rewards.length,
        itemBuilder: (context, index) {
          final reward = rewards[index];
          return _RewardCoupon(
            key: Key('loyalty-reward-${reward.id}'),
            reward: reward,
            canManage: canManage,
            onEdit: () => onEdit(reward),
            onToggle: () => onToggle(reward),
            onDelete: () => onDelete(reward),
          );
        },
      );
    },
  );
}

enum _RewardAction { edit, toggle, delete }

class _RewardCoupon extends StatelessWidget {
  const _RewardCoupon({
    super.key,
    required this.reward,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminLoyaltyReward reward;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final caption = loyaltyRewardTargetCaption(reward);
    final unavailable = !reward.targetIsAvailable;
    final accent = _accent(reward);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashFaint,
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 8, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminNetworkThumb(
                        imageUrl: reward.targetImageUrl,
                        size: 44,
                        icon: _targetIcon(reward.type),
                      ),
                      const SizedBox(width: AppSizes.px10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loyaltyRewardTargetName(reward),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: adminBodyColor(theme),
                                fontSize: AppFontSizes.size11_5,
                                fontWeight: AppFontWeights.bold,
                                height: AppTextHeights.line1_35,
                              ),
                            ),
                            const SizedBox(height: AppSizes.px2),
                            LoyaltyMoneyText(
                              sentence: caption,
                              style: TextStyle(
                                color: adminSubtleColor(theme),
                                fontSize: AppFontSizes.size9,
                                height: AppTextHeights.line1_5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canManage)
                        PopupMenuButton<_RewardAction>(
                          tooltip: S.loyaltyRewardMenuTooltip,
                          padding: EdgeInsets.zero,
                          onSelected: (action) => switch (action) {
                            _RewardAction.edit => onEdit(),
                            _RewardAction.toggle => onToggle(),
                            _RewardAction.delete => onDelete(),
                          },
                          itemBuilder: (context) => [
                            if (!unavailable)
                              PopupMenuItem(
                                value: _RewardAction.edit,
                                child: _MenuItem(
                                  icon: AppIcons.edit01,
                                  label: S.loyaltyRewardEdit,
                                ),
                              ),
                            if (!unavailable)
                              PopupMenuItem(
                                value: _RewardAction.toggle,
                                child: _MenuItem(
                                  icon: reward.isActive
                                      ? AppIcons.time01
                                      : AppIcons.checkmarkCircle02,
                                  label: reward.isActive
                                      ? S.loyaltyRewardPause
                                      : S.loyaltyRewardActivate,
                                ),
                              ),
                            PopupMenuItem(
                              value: _RewardAction.delete,
                              child: _MenuItem(
                                icon: AppIcons.delete02,
                                label: S.loyaltyRewardDelete,
                                destructive: true,
                              ),
                            ),
                          ],
                          child: SizedBox(
                            width: AppSizes.px28,
                            height: AppSizes.px28,
                            child: Center(
                              child: AppIcon(
                                AppIcons.moreHorizontalCircle01,
                                size: 17,
                                color: adminMutedColor(theme),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (unavailable)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 2,
                        bottom: 3,
                      ),
                      child: Row(
                        children: [
                          const AppIcon(
                            AppIcons.archive02,
                            size: 12,
                            color: AppColor.adminMuted,
                          ),
                          const SizedBox(width: AppSizes.px4),
                          Expanded(
                            child: Text(
                              S.loyaltyRewardUnavailable,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColor.adminMuted,
                                fontSize: AppFontSizes.size8_5,
                                height: AppTextHeights.line1_5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          _CouponPerforation(
            lineColor: adminControlBorderColor(theme),
            edgeColor: adminCardBorderColor(theme),
            notchColor: theme.colorScheme.surface,
          ),
          _PointsStub(reward: reward, accent: accent),
        ],
      ),
    );
  }

  static Color _accent(AdminLoyaltyReward reward) => switch (reward.state) {
    AdminLoyaltyRewardState.active => AppColor.adminAccent,
    AdminLoyaltyRewardState.paused => AppColor.adminWarning,
    AdminLoyaltyRewardState.outOfStock => AppColor.errorColor,
    AdminLoyaltyRewardState.unavailable => AppColor.adminMuted,
  };
}

IconData _targetIcon(AdminLoyaltyRewardType type) => switch (type) {
  AdminLoyaltyRewardType.product => AppIcons.package,
  AdminLoyaltyRewardType.bundle => AppIcons.shoppingBag01,
  AdminLoyaltyRewardType.plan => AppIcons.repeat,
};

class _CouponPerforation extends StatelessWidget {
  const _CouponPerforation({
    required this.lineColor,
    required this.edgeColor,
    required this.notchColor,
  });

  final Color lineColor;
  final Color edgeColor;
  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.px14,
      child: CustomPaint(
        painter: _CouponPerforationPainter(
          lineColor: lineColor,
          edgeColor: edgeColor,
          notchColor: notchColor,
        ),
      ),
    );
  }
}

class _CouponPerforationPainter extends CustomPainter {
  const _CouponPerforationPainter({
    required this.lineColor,
    required this.edgeColor,
    required this.notchColor,
  });

  final Color lineColor;
  final Color edgeColor;
  final Color notchColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const notchRadius = 6.0;
    const inset = 12.0;
    const dash = 4.0;
    const gap = 4.0;

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    var x = inset;
    while (x < size.width - inset) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width - inset), y),
        line,
      );
      x += dash + gap;
    }

    final notch = Paint()..color = notchColor;
    final edge = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final center in [Offset(0, y), Offset(size.width, y)]) {
      canvas.drawCircle(center, notchRadius, notch);
      canvas.drawCircle(center, notchRadius, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _CouponPerforationPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.edgeColor != edgeColor ||
      oldDelegate.notchColor != notchColor;
}

class _PointsStub extends StatelessWidget {
  const _PointsStub({required this.reward, required this.accent});

  final AdminLoyaltyReward reward;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = adminFlagForeground(theme, accent);
    final tint = adminFlagBackground(
      theme,
      accent,
      Color.lerp(accent, AppColor.whiteColor, .9)!,
    );
    return Container(
      color: tint,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.loyaltyRewardCouponCost,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            loyaltyCount(reward.pointsCost),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: AppFontSizes.size18,
                              fontWeight: AppFontWeights.extraBold,
                              height: AppTextHeights.line1_15,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.px4),
                        Text(
                          S.loyaltyPointUnit,
                          maxLines: 1,
                          style: TextStyle(
                            color: foreground,
                            fontSize: AppFontSizes.size8_5,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              AdminStatusBadge(
                label: loyaltyRewardStatusLabel(reward),
                color: _statusColor(reward),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px4),
          Row(
            children: [
              AppIcon(
                AppIcons.package,
                size: 12,
                color: reward.isOutOfStock
                    ? AppColor.errorColor
                    : adminMutedColor(theme),
              ),
              const SizedBox(width: AppSizes.px4),
              Expanded(
                child: Text(
                  loyaltyRewardStockText(reward),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reward.isOutOfStock
                        ? AppColor.errorColor
                        : adminMutedColor(theme),
                    fontSize: AppFontSizes.size8_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ),
              AppIcon(AppIcons.gift, size: 12, color: adminMutedColor(theme)),
              const SizedBox(width: AppSizes.px4),
              Flexible(
                child: Text(
                  loyaltyRewardRedemptionsText(reward),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size8_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(AdminLoyaltyReward reward) =>
      switch (reward.state) {
        AdminLoyaltyRewardState.active => AppColor.trendPositive,
        AdminLoyaltyRewardState.paused => AppColor.adminWarning,
        AdminLoyaltyRewardState.outOfStock => AppColor.errorColor,
        AdminLoyaltyRewardState.unavailable => AppColor.adminMuted,
      };
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColor.errorColor
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        AppIcon(icon, size: 16, color: color),
        const SizedBox(width: AppSizes.px8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: AppFontSizes.size11_5),
          ),
        ),
      ],
    );
  }
}
