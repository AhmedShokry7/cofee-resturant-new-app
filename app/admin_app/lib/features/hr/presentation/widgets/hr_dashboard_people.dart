import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_dashboard_tile.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_metric_grid.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// أقسام الأشخاص في لوحة القوى العاملة: عدّة الفريق، وحضور اليوم، وقرارات تنتظر.
///
/// كل باب يُرسم بما أرسلته القاعدة فقط: ما لم يُرسل يُقال إنه غير متاح، ولا
/// يُعدّ صفرًا ولا يُحذف فيُظن أن الباب أُغلق.
class HrDashboardPeople extends StatelessWidget {
  const HrDashboardPeople({
    super.key,
    required this.dashboard,
    required this.availableDestinations,
    this.onNavigate,
  });

  final HrDashboard dashboard;
  final Set<String> availableDestinations;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(
        S.hrHeadcount,
        AdminMetricGrid(
          children: [
            hrCountTile(
              icon: AppIcons.userCheck01,
              tint: AppColor.adminAccent,
              surface: AppColor.adminAccentSurface,
              label: S.hrActiveCount,
              count: dashboard.headcount.active,
            ),
            hrCountTile(
              icon: AppIcons.alarmClock,
              tint: AppColor.adminWarning,
              surface: AppColor.adminWarningSurface,
              label: S.hrOnProbation,
              count: dashboard.headcount.probation,
            ),
            hrCountTile(
              icon: AppIcons.calendar01,
              tint: AppColor.adminInfo,
              surface: AppColor.adminInfoSurface,
              label: S.hrOnLeaveToday,
              count: dashboard.headcount.onLeave,
            ),
            hrCountTile(
              icon: AppIcons.userBlock01,
              tint: AppColor.trendNegative,
              surface: AppColor.trendNegativeSurface,
              label: S.hrTerminatedCount,
              count: dashboard.headcount.terminated,
            ),
            hrCountTile(
              icon: AppIcons.userGroup,
              tint: AppColor.adminMuted,
              surface: AppColor.adminAccentSurface,
              label: S.hrHeadcount,
              count: dashboard.headcount.total,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _section(S.hrSectionAttendance, _today()),
      const SizedBox(height: AppSpacing.md),
      _section(S.hrPendingSection, _pending()),
    ],
  );

  /// حضور اليوم: تسأل عنه القاعدة، و`null` معناها أن السائل ليس من يسأل.
  Widget _today() {
    final today = dashboard.todayAttendance;
    if (today == null) return _unavailable();
    return AdminMetricGrid(
      children: [
        hrCountTile(
          icon: AppIcons.calendar03,
          tint: AppColor.adminInfo,
          surface: AppColor.adminInfoSurface,
          label: S.hrScheduledToday,
          count: today.scheduled,
        ),
        hrCountTile(
          icon: AppIcons.tick01,
          tint: AppColor.trendPositive,
          surface: AppColor.trendPositiveSurface,
          label: S.hrPresentToday,
          count: today.present,
        ),
        hrCountTile(
          icon: AppIcons.clock01,
          tint: AppColor.adminAccent,
          surface: AppColor.adminAccentSurface,
          label: S.hrOpenSessions,
          count: today.open,
        ),
        hrCountTile(
          icon: AppIcons.alert01,
          tint: AppColor.trendNegative,
          surface: AppColor.trendNegativeSurface,
          label: S.hrColLate,
          count: today.late,
        ),
      ],
    );
  }

  /// الأبواب التي تنتظر قرار هذا السائل وحده؛ ما لا يملك عدّه لا يُعرض عليه.
  Widget _pending() {
    final pending = dashboard.pending;
    final doors = <Widget>[
      if (pending.leaveRequests != null)
        _doorTile(
          S.hrPendingLeaves,
          pending.leaveRequests,
          AppIcons.calendar01,
          'hrLeave',
        ),
      if (pending.attendanceCorrections != null)
        _doorTile(
          S.hrPendingCorrections,
          pending.attendanceCorrections,
          AppIcons.note01,
          'hrAttendance',
        ),
      if (pending.advances != null)
        _doorTile(
          S.hrPendingAdvances,
          pending.advances,
          AppIcons.wallet01,
          'hrAdvances',
        ),
      if (pending.adjustments != null)
        _doorTile(
          S.hrSectionAdjustments,
          pending.adjustments,
          AppIcons.coins01,
          'hrAdvances',
        ),
      if (pending.discrepancies != null)
        _doorTile(
          S.hrPendingDiscrepancies,
          pending.discrepancies,
          AppIcons.cashier,
          'hrDiscrepancies',
        ),
    ];
    if (doors.isEmpty) return _unavailable();
    return AdminMetricGrid(children: doors);
  }

  Widget _doorTile(
    String label,
    int? count,
    IconData icon,
    String destination,
  ) {
    final tile = hrCountTile(
      icon: icon,
      tint: AppColor.adminWarning,
      surface: AppColor.adminWarningSurface,
      label: label,
      count: count,
    );
    if (onNavigate == null || !availableDestinations.contains(destination)) {
      return tile;
    }
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onNavigate!(destination),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: tile,
      ),
    );
  }

  Widget _section(String title, Widget child) =>
      AdminSectionCard(title: title, child: child);

  Widget _unavailable() => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: AdminEmptyState(
      icon: AppIcons.securityCheck,
      message: S.hrUnavailable,
    ),
  );
}
