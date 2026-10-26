import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_actions_menu.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_badges.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class CouponCards extends StatelessWidget {
  const CouponCards({
    super.key,
    required this.coupons,
    required this.canManage,
    required this.onOpen,
    required this.onCopy,
    required this.onToggle,
    required this.onDelete,
  });

  final List<AdminCoupon> coupons;
  final bool canManage;
  final ValueChanged<AdminCoupon> onOpen;
  final ValueChanged<AdminCoupon> onCopy;
  final ValueChanged<AdminCoupon> onToggle;
  final ValueChanged<AdminCoupon> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: coupons.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return _CouponCard(
          key: Key('coupon-card-${coupon.id}'),
          coupon: coupon,
          canManage: canManage,
          onOpen: () => onOpen(coupon),
          onCopy: () => onCopy(coupon),
          onToggle: () => onToggle(coupon),
          onDelete: () => onDelete(coupon),
        );
      },
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    super.key,
    required this.coupon,
    required this.canManage,
    required this.onOpen,
    required this.onCopy,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminCoupon coupon;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description =
        coupon.descriptionFor(AppLocale.instance.language) ??
        couponScopeHint(coupon);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: canManage ? onOpen : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CouponDiscountTile(coupon: coupon, size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.titleFor(AppLocale.instance.language),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size12,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminSubtleColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  CouponStatusBadge(coupon: coupon),
                  if (canManage)
                    CouponActionsMenu(
                      coupon: coupon,
                      onAction: (action) {
                        switch (action) {
                          case CouponAction.edit:
                            onOpen();
                          case CouponAction.toggle:
                            onToggle();
                          case CouponAction.delete:
                            onDelete();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: CouponCodeChip(
                      key: Key('coupon-copy-${coupon.id}'),
                      code: coupon.code,
                      onCopy: onCopy,
                    ),
                  ),
                  const Spacer(),
                  if (couponDiscountDetail(coupon).isNotEmpty)
                    Flexible(
                      child: Text(
                        couponDiscountDetail(coupon),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size8_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              CouponDashedLine(color: adminRowBorderColor(theme)),
              const SizedBox(height: 11),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 11,
                    children: [
                      SizedBox(
                        width: width,
                        child: _Stat(
                          icon: HugeIcons.strokeRoundedTag01,
                          label: S.couponsTableScope,
                          value: couponScopeLabel(coupon),
                          caption: couponScopeHint(coupon),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _Stat(
                          icon: HugeIcons.strokeRoundedRefresh,
                          label: S.couponsTableUsage,
                          value: couponUsageLabel(coupon),
                          caption: coupon.usageLimit == null
                              ? S.couponsUnlimited
                              : S.couponsRemaining(coupon.remainingUses ?? 0),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _Stat(
                          icon: HugeIcons.strokeRoundedCoins01,
                          label: S.couponsTableGiven,
                          value: couponPerformanceLabel(coupon),
                          caption: couponPerformanceDetail(coupon),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _Stat(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          label: S.couponsTableWindow,
                          value: couponWindowDetail(coupon),
                          caption: couponWindowLabel(coupon),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(icon: icon, size: 14, color: adminMutedColor(theme)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size8_5,
                  height: AppTextHeights.line1_4,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColor.adminAmount,
                  fontSize: AppFontSizes.size10,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminSubtleColor(theme),
                  fontSize: AppFontSizes.size8,
                  height: AppTextHeights.line1_4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
