import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/customer_previous_order_item.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class CustomerPreviousOrders extends StatelessWidget {
  const CustomerPreviousOrders({
    super.key,
    required this.orders,
    required this.loading,
    required this.failed,
    this.onOpen,
  });

  final List<AdminOrder> orders;
  final bool loading, failed;
  final ValueChanged<AdminOrder>? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: AppSizes.px18,
            height: AppSizes.px18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColor.adminAccent,
            ),
          ),
        ),
      );
    } else if (orders.isEmpty) {
      body = Text(
        failed ? S.customerHistoryLoadFailed : S.ordersNoPreviousOrders,
        style: TextStyle(
          color: adminMutedColor(theme),
          fontSize: AppFontSizes.size11,
          height: AppTextHeights.line1_5,
        ),
      );
    } else {
      // كل طلبات العميل تُطبع: الشارة فوق القسم عددُها كله، فكان سقفٌ خامس
      // يخفي الباقي بصمتٍ ويترك العدّ فوق يقول غير ما يرى الأدمن. صفحة
      // التمرير تتّسع لهم، والمصدر مرتّبٌ الأحدث أولًا.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < orders.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSizes.px8),
            CustomerPreviousOrderItem(
              order: orders[index],
              onTap: onOpen == null ? null : () => onOpen!(orders[index]),
            ),
          ],
        ],
      );
    }
    return AdminSectionCard(
      title: S.ordersCustomerHistory,
      count: loading ? null : orders.length,
      child: body,
    );
  }
}
