import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderAddProductButton extends StatelessWidget {
  const OrderAddProductButton({
    super.key,
    required this.order,
    required this.onPressed,
  });

  final AdminOrder order;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = OrderEditRules.canEditItems(order);
    final iconColor = enabled ? AppColor.whiteColor : adminMutedColor(theme);
    return Tooltip(
      message: enabled ? S.ordersAddProduct : S.orderCannotBeEdited,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColor.adminAccent,
          foregroundColor: AppColor.whiteColor,
          disabledBackgroundColor: adminIsDark(theme)
              ? AppColor.darkCard
              : AppColor.lightGreyColor,
          disabledForegroundColor: adminMutedColor(theme),
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: AppFontSizes.size10_5,
            fontWeight: AppFontWeights.semiBold,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          size: 15,
          color: iconColor,
        ),
        label: Text(S.ordersAddProduct, maxLines: 1),
      ),
    );
  }
}
