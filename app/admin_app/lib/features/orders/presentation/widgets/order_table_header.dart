import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table.dart';

class OrderTableHeader extends StatelessWidget {
  const OrderTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _cell(S.orderNumber, dark)),
          Expanded(flex: 3, child: _cell(S.customer, dark)),
          Expanded(flex: 2, child: _cell(S.date, dark)),
          Expanded(flex: 3, child: _cell(S.orderItemsLabel, dark)),
          Expanded(flex: 2, child: _cell(S.total, dark)),
          Expanded(flex: 2, child: _cell(S.ordersStatus, dark)),
          const SizedBox(width: OrderTable.actionWidth),
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
