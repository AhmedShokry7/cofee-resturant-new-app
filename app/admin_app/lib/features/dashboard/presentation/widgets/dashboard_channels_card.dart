import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/fulfillment_type.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_channel_legend_row.dart';
import 'package:admin_app/shared/widgets/admin_donut_chart.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_icon_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// مال كل قناة استلام من مال آخر ثلاثين يومًا، على حلقة ومفتاحها.
///
/// الدونات يُرسم على المال لا على العدد: الأدمن يسأل «أي قناة تجلب المتجر؟»،
/// وعدد الطلبات يبقى مكتوبًا في المفتاح لأن النسبة وحدها تُخفي قناةً طلباتها
/// كثيرة ومالها قليل. والأسماء من `fulfillmentLabel` نفسها التي تسمّي الطلب في
/// شاشة الطلبات والمطبخ، فلا يختلف اسم القناة بين شاشة وأخرى.
class DashboardChannelsCard extends StatelessWidget {
  const DashboardChannelsCard({super.key, required this.metrics});

  final AdminDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final total = metrics.channelRevenueTotal;
    return AdminSectionCard(
      title: S.dashboardChannelsTitle,
      subtitle: S.dashboardChannelsSubtitle,
      leading: const AdminIconBadge(
        icon: AppIcons.deliveryTruck01,
        surface: AppColor.adminInfoSurface,
        color: AppColor.adminInfo,
      ),
      child: total <= 0
          ? AdminEmptyState(
              icon: AppIcons.deliveryTruck01,
              message: S.dashboardChannelsEmpty,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _ring(total)),
                const SizedBox(height: AppSizes.px12),
                for (final (index, slice) in metrics.channels.indexed)
                  DashboardChannelLegendRow(
                    slice: slice,
                    color: dashboardChannelColor(index),
                    share: metrics.shareOf(slice.revenue, total),
                    channelLabel: fulfillmentLabel(slice.channel),
                  ),
              ],
            ),
    );
  }

  /// الرقم في الفتحة مختصرًا: «٢٤ ألف» تُقارَن، ومبلغ كامل بخمس خانات لا
  /// يسعها فتحة قطرها مئة وخمسون.
  Widget _ring(double total) => AdminDonutChart(
    slices: [
      for (final (index, slice) in metrics.channels.indexed)
        AdminDonutSlice(
          label: fulfillmentLabel(slice.channel),
          value: slice.revenue,
          color: dashboardChannelColor(index),
        ),
    ],
    centerValue: dashboardAxisValue(total),
    centerLabel: S.dashboardSalesLegend,
  );
}
