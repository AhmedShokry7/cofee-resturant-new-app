import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum CouponAction { edit, toggle, delete }

class CouponActionsMenu extends StatelessWidget {
  const CouponActionsMenu({
    super.key,
    required this.coupon,
    required this.onAction,
  });

  final AdminCoupon coupon;
  final ValueChanged<CouponAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopupMenuButton<CouponAction>(
      key: Key('coupon-menu-${coupon.id}'),
      tooltip: S.couponsMenuTooltip,
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem<CouponAction>(
          value: CouponAction.edit,
          child: _item(
            theme,
            icon: AppIcons.pencilEdit02,
            label: S.couponsEdit,
            direction: rtl,
          ),
        ),
        PopupMenuItem<CouponAction>(
          value: CouponAction.toggle,
          child: _item(
            theme,
            icon: coupon.isActive ? AppIcons.pause : AppIcons.play,
            label: coupon.isActive ? S.couponsPause : S.couponsActivate,
            direction: rtl,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<CouponAction>(
          value: CouponAction.delete,
          child: _item(
            theme,
            icon: AppIcons.delete02,
            label: S.couponsDelete,
            direction: rtl,
            color: AppColor.errorColor,
          ),
        ),
      ],
      child: AppIcon(
        AppIcons.moreHorizontal,
        size: 18,
        color: adminMutedColor(theme),
      ),
    );
  }

  Widget _item(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool direction,
    Color? color,
  }) => Row(
    textDirection: direction ? TextDirection.rtl : TextDirection.ltr,
    children: [
      AppIcon(icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: AppSizes.px8),
      Text(
        label,
        style: TextStyle(
          color: color ?? adminBodyColor(theme),
          fontSize: AppFontSizes.size11,
          height: AppTextHeights.line1_5,
        ),
      ),
    ],
  );
}
