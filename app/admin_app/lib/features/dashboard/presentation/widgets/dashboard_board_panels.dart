import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_visible_rows.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_channels_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_growth_banner.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_metrics_cards.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_recent_orders_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_sales_overview_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_setup_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_top_products_panel.dart';
import 'package:admin_app/shared/widgets/admin_panel_row.dart';
import 'package:admin_app/shared/widgets/admin_reveal.dart';

/// لوحات اللوحة بترتيب قراءتها: قصة النمو، ثم أرقامه، ثم تفصيله.
///
/// كل صف لوحَتين: واحدة تشرح والأخرى تُفصِّل، والعمود الضيّق (٥٣ من ١٥٣)
/// للبطاقة التي تُقرأ في سطر واحد. ولو حُشرت اللوحات الخمس عشرة في عمود واحد
/// لصارت اللوحة قائمة هاتف ممدودة على شاشة مكتب. والظهور التدريجي هنا لا في
/// الصفحة، فلا بطاقة تملك قرار موعدها.
class DashboardBoardPanels extends StatelessWidget {
  const DashboardBoardPanels({
    super.key,
    required this.state,
    required this.rows,
    required this.canManageTarget,
    required this.onRangeChanged,
    required this.onEditTarget,
  });

  final AdminDashboardState state;
  final DashboardVisibleRows rows;

  /// مدير الفرع الواحد لا يقرأ هدف الشركة ولا يكتبه: رقمٌ عام أمام فرع واحد
  /// يُقرأ خطأً على أنه هدفُه.
  final bool canManageTarget;
  final ValueChanged<int> onRangeChanged;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, panel) in _panels().indexed) ...[
          if (index > 0) const SizedBox(height: AppSizes.px14),
          AdminReveal(index: index, child: panel),
        ],
      ],
    );
  }

  List<Widget> _panels() {
    final metrics = state.metrics;
    final empty = rows.emptyMessage;
    return [
      DashboardGrowthBanner(metrics: metrics, rangeDays: state.salesRangeDays),
      DashboardMetricsCards(metrics: metrics),
      _row(
        canManageTarget
            ? DashboardTargetCard(
                metrics: metrics,
                saving: state.isSavingTarget,
                onEditTarget: onEditTarget,
              )
            : null,
        DashboardSalesOverviewCard(
          metrics: metrics,
          rangeDays: state.salesRangeDays,
          onRangeChanged: onRangeChanged,
        ),
      ),
      _row(
        dashboardVisibleSetupSteps(metrics).isEmpty
            ? null
            : DashboardSetupCard(metrics: metrics),
        DashboardRecentOrdersCard(orders: rows.orders, emptyMessage: empty),
      ),
      _row(
        DashboardChannelsCard(metrics: metrics),
        DashboardTopProductsPanel(
          products: rows.products,
          metrics: metrics,
          emptyMessage: empty,
        ),
      ),
    ];
  }

  /// صف بلوحة جانبية قد لا تكون: إذا غاب الهدف أو خطوات البداية تأخذ اللوحة
  /// العريضة العرض كله، لأن نصف صفحة فارغ يُقرأ خللًا لا قرارًا.
  Widget _row(Widget? narrow, Widget wide) => AdminPanelRow(
    weights: narrow == null ? null : const [53, 100],
    children: narrow == null ? [wide] : [narrow, wide],
  );
}
