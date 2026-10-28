import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// سطر طلب واحد في جدول اللوحة: من طلب، وكم دفع، وأين صار.
///
/// الأعمدة الخمسة تُقرأ من الأرقام نفسها التي تُطبع في شاشة الطلبات، فاللوحة
/// صورة مصغّرة لا مصدر ثانٍ للحقيقة. ورقم الطلب يبقى لاتينيًا لأنه مُعرَّف
/// يُفتَّش به لا مقدار يُقرأ، والحالة شارة بلونها واسمها لأن اللون وحده لا يُقال.
class DashboardOrderRow extends StatelessWidget {
  const DashboardOrderRow({super.key, required this.order});

  final AdminDashboardRecentOrder order;

  String get _customer {
    final name = (order.customerName ?? '').trim();
    return name.isEmpty ? S.dashboardAnonymousCustomer : name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = OrderStatusView.of(order.status);
    final cells = <Widget>[
      _cellText(
        order.orderNumber,
        AppColor.adminAccent,
        AppFontWeights.semiBold,
      ),
      _cellText(_customer, adminBodyColor(theme), AppFontWeights.regular),
      _cellText(
        localizedDateTime(order.placedAt),
        adminDateColor(theme),
        AppFontWeights.regular,
      ),
      _cellText(
        formatMoneyWithCurrency(order.grandTotal),
        adminAmountColor(theme),
        AppFontWeights.semiBold,
      ),
      AdminStatusBadge(label: status.label, color: status.color),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.px8,
        vertical: AppSizes.px10,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          for (final (index, cell) in cells.indexed) ...[
            Expanded(flex: dashboardOrderColumnFlexes[index], child: cell),
            if (index < cells.length - 1) const SizedBox(width: AppSizes.px6),
          ],
        ],
      ),
    );
  }

  Widget _cellText(String text, Color color, FontWeight weight) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontSize: AppFontSizes.size10,
      fontWeight: weight,
      height: AppTextHeights.line1_4,
    ),
  );
}
