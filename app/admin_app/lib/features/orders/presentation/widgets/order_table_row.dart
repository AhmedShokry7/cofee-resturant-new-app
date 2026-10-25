import 'package:flutter/material.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_status_pill.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_row_cells.dart';

class OrderTableRow extends StatelessWidget {
  const OrderTableRow({super.key, required this.order, this.onTap});
  final AdminOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F0))),
      ),
      child: Row(
        children: [
          _cell(2, OrderTableRowCells.orderNumber(order.orderNumber)),
          _cell(3, OrderTableRowCells.customer(order)),
          _cell(2, OrderTableRowCells.date(order.placedAt)),
          _cell(3, OrderTableRowCells.product(order)),
          _cell(2, OrderTableRowCells.amount(order.grandTotal)),
          _cell(2, OrderTableStatusPill(status: order.status)),
        ],
      ),
    ),
  );

  Widget _cell(int flex, Widget child) => Expanded(flex: flex, child: child);
}
