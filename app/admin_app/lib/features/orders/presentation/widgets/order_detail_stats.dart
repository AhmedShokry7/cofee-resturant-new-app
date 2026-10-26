import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';

class OrderDetailStats extends StatelessWidget {
  const OrderDetailStats({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fulfillment = OrderFulfillmentView.of(order.fulfillmentType);
    final payment = OrderPaymentStatusView.of(order.paymentStatus);
    final paymentColor = dark
        ? Color.lerp(payment.color, AppColor.whiteColor, .35)!
        : payment.color;

    final tiles = <Widget>[
      AdminStatTile(
        icon: AppIcons.receiptDollar,
        tint: AppColor.adminWarning,
        surface: AppColor.adminWarningSurface,
        money: order.grandTotal,
        moneyFormatter: orderMoney,
        label: S.grandTotal,
      ),
      AdminStatTile(
        icon: AppIcons.package,
        tint: AppColor.adminAccent,
        surface: AppColor.adminAccentSurface,
        value: orderCount(order.items.length),
        label: S.orderItemsLabel,
      ),
      AdminStatTile(
        icon: AppIcons.deliveryBox01,
        tint: AppColor.adminInfo,
        surface: AppColor.adminInfoSurface,
        value: fulfillment.label,
        label: S.fulfillmentType,
      ),
      AdminStatTile(
        icon: AppIcons.payment01,
        tint: AppColor.trendPositive,
        surface: AppColor.trendPositiveSurface,
        value: payment.label,
        valueColor: paymentColor,
        label: S.paymentStatusLabelTitle,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        const gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}
