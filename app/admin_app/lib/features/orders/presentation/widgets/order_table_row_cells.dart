import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_date_cell.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class OrderTableRowCells {
  static Widget orderNumber(String value) => Text(
    '#$value',
    style: const TextStyle(
      color: Color(0xFF267660),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );

  static Widget customer(AdminOrder order) => Row(
    children: [
      AdminAvatarImage(url: order.customerAvatarUrl, size: 29),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          order.customerName ?? S.ordersUnknownCustomer,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF49584F), fontSize: 11),
        ),
      ),
    ],
  );

  static Widget product(AdminOrder order) {
    if (order.items.isEmpty) return Text(S.noOrderItems, style: _textStyle);
    final item = order.items.first;
    final name = item.productNameFor(AppLocale.instance.language);
    final label = item.quantity > 1
        ? '$name × ${OrderSummaryMetricFormat.count(item.quantity)}'
        : name;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _textStyle,
    );
  }

  static Widget amount(double value) => Row(
    children: [
      Text(
        formatAmount(value),
        style: const TextStyle(
          color: Color(0xFF36473E),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 4),
      const CurrencyIcon(size: 13),
    ],
  );

  static Widget date(DateTime? value) => OrderTableDateCell(value: value);

  static const _textStyle = TextStyle(
    color: Color(0xFF49584F),
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );
}
