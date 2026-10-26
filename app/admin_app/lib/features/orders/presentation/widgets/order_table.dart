import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_row.dart';

class OrderTable extends StatelessWidget {
  const OrderTable({super.key, required this.orders, this.onOpen});

  final List<AdminOrder> orders;
  final ValueChanged<AdminOrder>? onOpen;

  static const double actionWidth = 44;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 1000), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const OrderTableHeader(),
                for (final order in orders)
                  OrderTableRow(
                    order: order,
                    onTap: onOpen == null ? null : () => onOpen!(order),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
