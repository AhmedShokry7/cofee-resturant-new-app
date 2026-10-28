import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_orders_table.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_section_link.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// أحدث ستة طلبات وصلت، في جدول برؤوسه.
///
/// جدول لا قائمة بطاقات، لأن الأدمن يقارن الحالات والمبالغ بأعمدة لا بأسطر
/// متفرقة، ولأن شاشة الطلبات تعرض الطلب كاملًا بينما هنا يكفي سطره.
/// والشارة عدد ما يُعرض فعلًا: يبحث الأدمن فينقص الرقم لا النص.
class DashboardRecentOrdersCard extends StatelessWidget {
  const DashboardRecentOrdersCard({
    super.key,
    required this.orders,
    required this.emptyMessage,
  });

  final List<AdminDashboardRecentOrder> orders;

  /// سبب الفراغ: لا طلب بعد، أو أن البحث لم يترك سطرًا.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => AdminSectionCard(
    title: S.recentOrders,
    subtitle: S.dashboardRecentOrdersSubtitle,
    count: orders.isEmpty ? null : orders.length,
    trailing: AdminSectionLink(
      destinationId: 'orders',
      label: S.dashboardViewAllOrders,
      icon: AppIcons.arrowLeft01,
    ),
    child: orders.isEmpty
        ? AdminEmptyState(icon: AppIcons.receiptDollar, message: emptyMessage)
        : DashboardOrdersTable(orders: orders),
  );
}
