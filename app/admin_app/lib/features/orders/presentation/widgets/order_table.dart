import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_row.dart';

class OrderTable extends StatelessWidget {
  const OrderTable({
    super.key,
    required this.orders,
    this.onOpen,
    this.onChangeStatus,
    this.canManage = true,
    this.statusRules,
  });

  final List<AdminOrder> orders;
  final ValueChanged<AdminOrder>? onOpen;

  /// تحريك حالة طلب، وهو ما تعرضه البطاقات نفسها في الشاشة الضيقة؛ يتركه الدور
  /// الذي يقرأ الطلبات فقط غير ممرَّر فتبقى الخانات بلا قائمة.
  final void Function(AdminOrder order, String status)? onChangeStatus;
  final bool canManage;

  /// الانتقالات المسموحة كما قرأتها القاعدة؛ `null` قبل القراءة.
  final OrderStatusRules? statusRules;

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
                    onChangeStatus: onChangeStatus == null || !canManage
                        ? null
                        : (status) => onChangeStatus!(order, status),
                    allowedStatuses: statusRules?.allowedFor(order.status),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
