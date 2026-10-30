import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_dashboard_tile.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/shared/widgets/admin_metric_grid.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// أقسام المال في اللوحة: ما ينتظر التسوية، ودورة الشهر، وموضع الموظف نفسه.
///
/// الرواتب أخصّ بيانات الفيتشر، فتُعرض بالقطعة التي أرسلتها القاعدة لا بقدر ما
/// تجمع الشاشة: عدّة من عدّها، ومبلغ من أرسلته، وكلمة «غير متاح» لغير المصرّح.
class HrDashboardMoney extends StatelessWidget {
  const HrDashboardMoney({super.key, required this.dashboard});

  final HrDashboard dashboard;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(
        S.hrFinanceSection,
        AdminMetricGrid(
          children: [
            hrCountTile(
              icon: AppIcons.cashier,
              tint: AppColor.adminWarning,
              surface: AppColor.adminWarningSurface,
              label: S.hrOpenShortages,
              count: dashboard.finance?.openDiscrepancies,
            ),
            hrMoneyTile(
              icon: AppIcons.alert02,
              tint: AppColor.trendNegative,
              surface: AppColor.trendNegativeSurface,
              label: S.hrOpenShortageValue,
              amount: dashboard.finance?.openDiscrepancyAmount,
            ),
            hrMoneyTile(
              icon: AppIcons.wallet01,
              tint: AppColor.adminInfo,
              surface: AppColor.adminInfoSurface,
              label: S.hrAdvancesOutstanding,
              amount: dashboard.finance?.advancesOutstanding,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _section(S.hrPayroll, _payroll()),
      const SizedBox(height: AppSpacing.md),
      _section(S.hrMyDay, _me()),
    ],
  );

  Widget _payroll() {
    final payroll = dashboard.payroll;
    final run = payroll?.run;
    final period = payroll == null
        ? S.hrUnavailable
        : '${localizedMonthName(payroll.periodMonth)} '
              '${localizeDigits('${payroll.periodYear}')}';
    return AdminMetricGrid(
      children: [
        _textTile(
          AppIcons.calendar01,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
          S.hrColPeriod,
          period,
        ),
        if (run != null && run.isReal) ...[
          _textTile(
            AppIcons.taskDone01,
            AppColor.adminInfo,
            AppColor.adminInfoSurface,
            S.status,
            hrStatusLabel(run.status).text,
          ),
          _textTile(
            AppIcons.receiptDollar,
            AppColor.adminWarning,
            AppColor.adminWarningSurface,
            S.hrColStatements,
            localizeDigits('${run.statementCount}'),
          ),
          hrMoneyTile(
            icon: AppIcons.coins01,
            tint: AppColor.trendPositive,
            surface: AppColor.trendPositiveSurface,
            label: S.hrColNet,
            amount: run.totalNet,
          ),
        ] else
          _textTile(
            AppIcons.informationCircle,
            AppColor.adminMuted,
            AppColor.adminAccentSurface,
            S.hrLatestRun,
            S.hrRunNone,
          ),
      ],
    );
  }

  Widget _me() {
    final me = dashboard.me;
    final slip = me.latestPayslip;
    return AdminMetricGrid(
      children: [
        _textTile(
          AppIcons.clock01,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
          S.hrMyOpenShift,
          me.openSession == null ? S.hrMyNoOpenSession : S.hrMyOpenSession,
        ),
        _textTile(
          AppIcons.timer01,
          AppColor.adminInfo,
          AppColor.adminInfoSurface,
          S.hrWorkedToday,
          hrDuration(me.workedMinutesToday),
        ),
        hrCountTile(
          icon: AppIcons.calendar01,
          tint: AppColor.adminWarning,
          surface: AppColor.adminWarningSurface,
          label: S.hrMyLeaves,
          count: me.pendingLeave,
        ),
        // قسيمة لم تصدر تُقال كما هي: لا «غير متاح» ولا صفرٌ يُقرأ راتبًا.
        if (slip == null)
          _textTile(
            AppIcons.coins01,
            AppColor.adminMuted,
            AppColor.adminAccentSurface,
            S.hrMyPayslips,
            S.hrNoPayslipsYet,
          )
        else
          hrMoneyTile(
            icon: AppIcons.coins01,
            tint: AppColor.trendPositive,
            surface: AppColor.trendPositiveSurface,
            label:
                '${S.hrMyPayslips} • '
                '${localizedMonthName(slip.periodMonth)} '
                '${localizeDigits('${slip.periodYear}')}',
            amount: slip.net,
          ),
      ],
    );
  }

  Widget _textTile(
    IconData icon,
    Color tint,
    Color surface,
    String label,
    String value,
  ) => AdminStatTile(
    icon: icon,
    tint: tint,
    surface: surface,
    label: label,
    value: value,
  );

  Widget _section(String title, Widget child) =>
      AdminSectionCard(title: title, child: child);
}
