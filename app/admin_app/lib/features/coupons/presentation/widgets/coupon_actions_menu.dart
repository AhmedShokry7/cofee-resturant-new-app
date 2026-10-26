import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
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
            icon: HugeIcons.strokeRoundedPencilEdit02,
            label: S.couponsEdit,
            direction: rtl,
          ),
        ),
        PopupMenuItem<CouponAction>(
          value: CouponAction.toggle,
          child: _item(
            theme,
            icon: coupon.isActive
                ? HugeIcons.strokeRoundedPause
                : HugeIcons.strokeRoundedPlay,
            label: coupon.isActive ? S.couponsPause : S.couponsActivate,
            direction: rtl,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<CouponAction>(
          value: CouponAction.delete,
          child: _item(
            theme,
            icon: HugeIcons.strokeRoundedDelete02,
            label: S.couponsDelete,
            direction: rtl,
            color: AppColor.errorColor,
          ),
        ),
      ],
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
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
      HugeIcon(icon: icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: 8),
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
