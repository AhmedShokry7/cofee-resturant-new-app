import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_actions_menu.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_badges.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class CouponTable extends StatelessWidget {
  const CouponTable({
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

  static const _minWidth = 1320.0;
  static const _codeWidth = 130.0;
  static const _discountWidth = 130.0;
  static const _scopeWidth = 165.0;
  static const _usageWidth = 130.0;
  static const _givenWidth = 150.0;
  static const _windowWidth = 190.0;
  static const _statusWidth = 105.0;
  static const _actionWidth = 36.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, _minWidth), 1760)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final coupon in coupons)
                  _Row(
                    key: Key('coupon-row-${coupon.id}'),
                    coupon: coupon,
                    canManage: canManage,
                    onOpen: () => onOpen(coupon),
                    onCopy: () => onCopy(coupon),
                    onToggle: () => onToggle(coupon),
                    onDelete: () => onDelete(coupon),
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
          Expanded(child: _cell(S.couponsTableCoupon, dark)),
          SizedBox(
            width: CouponTable._codeWidth,
            child: _cell(S.couponsCodeLabel, dark),
          ),
          SizedBox(
            width: CouponTable._discountWidth,
            child: _cell(S.couponsTableDiscount, dark),
          ),
          SizedBox(
            width: CouponTable._scopeWidth,
            child: _cell(S.couponsTableScope, dark),
          ),
          SizedBox(
            width: CouponTable._usageWidth,
            child: _cell(S.couponsTableUsage, dark),
          ),
          SizedBox(
            width: CouponTable._givenWidth,
            child: _cell(S.couponsTableGiven, dark),
          ),
          SizedBox(
            width: CouponTable._windowWidth,
            child: _cell(S.couponsTableWindow, dark),
          ),
          SizedBox(
            width: CouponTable._statusWidth,
            child: _cell(S.couponsTableStatus, dark),
          ),
          const SizedBox(width: CouponTable._actionWidth),
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
  const _Row({
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
    final dark = adminIsDark(theme);
    final body = adminBodyColor(theme);
    final status = coupon.statusAt();
    final description =
        coupon.descriptionFor(AppLocale.instance.language) ??
        couponScopeHint(coupon);
    return Material(
      color: AppColor.transparent,
      child: InkWell(
        onTap: canManage ? onOpen : null,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    CouponDiscountTile(coupon: coupon),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coupon.titleFor(AppLocale.instance.language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: body,
                              fontSize: AppFontSizes.size11_5,
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
                  ],
                ),
              ),
              SizedBox(
                width: CouponTable._codeWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CouponCodeChip(
                    key: Key('coupon-copy-${coupon.id}'),
                    code: coupon.code,
                    onCopy: onCopy,
                  ),
                ),
              ),
              SizedBox(
                width: CouponTable._discountWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      couponDiscountHeadline(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? AppColor.darkText : AppColor.adminAmount,
                        fontSize: AppFontSizes.size11,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    if (couponDiscountDetail(coupon).isNotEmpty)
                      Text(
                        couponDiscountDetail(coupon),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size8_5,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: CouponTable._scopeWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      couponScopeLabel(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: body,
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      couponScopeHint(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: CouponTable._usageWidth,
                child: CouponUsageMeter(coupon: coupon),
              ),
              SizedBox(
                width: CouponTable._givenWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      couponPerformanceLabel(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: coupon.wasRedeemed
                            ? (dark ? AppColor.darkText : AppColor.adminAmount)
                            : adminMutedColor(theme),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      couponPerformanceDetail(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: CouponTable._windowWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      couponWindowLabel(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: body,
                        fontSize: AppFontSizes.size10,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      couponWindowDetail(coupon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: switch (status) {
                          AdminCouponStatus.expiringSoon =>
                            AppColor.adminWarning,
                          AdminCouponStatus.expired => AppColor.errorColor,
                          AdminCouponStatus.scheduled => AppColor.adminInfo,
                          _ => adminSubtleColor(theme),
                        },
                        fontSize: AppFontSizes.size8_5,
                        fontWeight: status == AdminCouponStatus.active
                            ? AppFontWeights.regular
                            : AppFontWeights.semiBold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: CouponTable._statusWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CouponStatusBadge(coupon: coupon),
                ),
              ),
              SizedBox(
                width: CouponTable._actionWidth,
                child: canManage
                    ? Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: CouponActionsMenu(
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
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
