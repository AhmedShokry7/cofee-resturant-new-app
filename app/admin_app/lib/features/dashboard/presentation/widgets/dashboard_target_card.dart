import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_facts.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_missing.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_ring.dart';
import 'package:admin_app/shared/widgets/admin_icon_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

/// هدف الشهر وحلقتُه في بطاقة واحدة.
///
/// الهدف رقم الشركة لا رقم فرع، فلا تُبنى البطاقة أصلًا لمن لا يدير كل الفروع:
/// هدفٌ عام أمام مدير فرع واحد يُقرأ خطأً على أنه هدفُه. وبلا هدف مكتوب لا
/// تُرسم حلقة: صفرٌ على مقياس لم يُضعه أحد كذب، فالبطاقة تسأل صاحبه أن يضعه.
class DashboardTargetCard extends StatelessWidget {
  const DashboardTargetCard({
    super.key,
    required this.metrics,
    required this.saving,
    required this.onEditTarget,
  });

  final AdminDashboardMetrics metrics;
  final bool saving;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    final target = metrics.monthlyRevenueTarget;
    final progress = metrics.targetProgress;
    return AdminSectionCard(
      title: S.dashboardTargetCardTitle,
      subtitle: S.dashboardTargetCardSubtitle,
      leading: const AdminIconBadge(
        icon: AppIcons.percent,
        surface: AppColor.tintGreenSurface,
        color: AppColor.tintGreenInk,
      ),
      trailing: _edit(context),
      child: target == null || progress == null
          ? const DashboardTargetMissing()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DashboardTargetRing(
                    progress: progress,
                    reached: metrics.monthRevenue >= target,
                  ),
                ),
                const SizedBox(height: AppSizes.px14),
                DashboardTargetFacts(metrics: metrics),
              ],
            ),
    );
  }

  /// زرّ الكتابة واحد في الرأس، فتُقرأ البطاقة وهي تُعدَّل لا وهي تُشرح.
  Widget _edit(BuildContext context) => CustomBtn(
    key: const Key('dashboard-target-edit'),
    text: metrics.hasMonthlyTarget
        ? S.dashboardTargetEdit
        : S.dashboardTargetSet,
    onPressed: saving ? null : onEditTarget,
    isLoading: saving,
    variant: BtnVariant.outlined,
    height: AppSizes.px30,
    borderRadius: AppRadius.pill,
    leadingIcon: AppIcon(
      AppIcons.edit01,
      size: AppSizes.px14,
      color: adminMutedColor(Theme.of(context)),
    ),
  );
}
