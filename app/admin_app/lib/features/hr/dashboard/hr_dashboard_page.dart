import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/app_locale.dart';
import '../../../core/locale/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/admin_page_frame.dart';
import '../../../shared/widgets/admin_page_header.dart';
import '../../../shared/widgets/admin_state_view.dart';
import '../../../shared/widgets/app_icon.dart';
import 'hr_dashboard_cubit.dart';

class HrDashboardPage extends StatefulWidget {
  const HrDashboardPage({super.key, this.cubit});
  final HrDashboardCubit? cubit;

  @override
  State<HrDashboardPage> createState() => _HrDashboardPageState();
}

class _HrDashboardPageState extends State<HrDashboardPage> {
  late final HrDashboardCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrDashboardCubit();
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrDashboardCubit, HrDashboardState>(
      builder: (context, state) {
        if (state.status == HrDashboardStatus.loading && state.data.isEmpty) {
          return const AdminLoadingView();
        }
        if (state.status == HrDashboardStatus.failure && state.data.isEmpty) {
          return AdminFailureView(
            message: state.error ?? '',
            onRetry: _cubit.load,
          );
        }
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.hrDashboard,
                subtitle: S.hrDashboardSubtitle,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: state.branchId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: S.hrBranch,
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(S.hrAllBranches),
                      ),
                      for (final branch in state.branches)
                        DropdownMenuItem(
                          value: branch['id']?.toString(),
                          child: Text(_branchName(branch)),
                        ),
                    ],
                    onChanged: _cubit.setBranch,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _DashboardContent(data: state.data)),
            ],
          ),
        );
      },
    ),
  );

  String _branchName(Map<String, dynamic> branch) {
    final arabic = AppLocale.instance.isArabic;
    final name = branch[arabic ? 'name_ar' : 'name_en']?.toString();
    final fallback = branch[arabic ? 'name_en' : 'name_ar']?.toString();
    return name?.isNotEmpty == true ? name! : fallback ?? '';
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final headcount = _map(data['headcount']);
    final attendance = _map(data['today_attendance']);
    final pending = _map(data['pending']);
    final finance = _map(data['finance']);
    final payroll = _map(data['payroll']);
    final run = _map(payroll['run']);
    final cards = <Widget>[
      if (headcount.isNotEmpty) ...[
        _metric(S.hrTotalEmployees, headcount['total'], AppIcons.userMultiple),
        _metric(S.hrActiveEmployees, headcount['active'], AppIcons.userCheck01),
        _metric(
          S.hrProbationEmployees,
          headcount['probation'],
          AppIcons.time01,
        ),
        _metric(
          S.hrOnLeaveEmployees,
          headcount['on_leave'],
          AppIcons.calendar01,
        ),
      ],
      if (attendance.isNotEmpty) ...[
        _metric(
          S.hrScheduledToday,
          attendance['scheduled'],
          AppIcons.calendarAdd01,
        ),
        _metric(S.hrPresentToday, attendance['present'], AppIcons.userCheck01),
        _metric(S.hrOpenAttendance, attendance['open'], AppIcons.alarmClock),
        _metric(S.hrLateToday, attendance['late'], AppIcons.time01),
      ],
      if (pending.isNotEmpty) ...[
        _metric(
          S.hrPendingLeave,
          pending['leave_requests'],
          AppIcons.calendar01,
        ),
        _metric(
          S.hrPendingCorrections,
          pending['attendance_corrections'],
          AppIcons.edit01,
        ),
        _metric(S.hrPendingAdvances, pending['advances'], AppIcons.wallet01),
        _metric(
          S.hrPendingAdjustments,
          pending['adjustments'],
          AppIcons.money01,
        ),
        _metric(
          S.hrPendingDiscrepancies,
          pending['discrepancies'],
          AppIcons.alert,
        ),
      ],
      if (finance.isNotEmpty) ...[
        _metric(
          S.hrOutstandingAdvances,
          finance['advances_outstanding'],
          AppIcons.wallet01,
        ),
        _metric(
          S.hrOpenDiscrepancies,
          finance['open_discrepancies'],
          AppIcons.alert,
        ),
      ],
    ];
    return ListView(
      children: [
        if (cards.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              crossAxisCount: constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 700
                  ? 3
                  : constraints.maxWidth > 440
                  ? 2
                  : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: constraints.maxWidth < 440 ? 3.2 : 1.9,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              children: cards,
            ),
          ),
        if (payroll.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const AppIcon(AppIcons.money01),
              title: Text(S.hrPayrollCurrentPeriod),
              subtitle: Text(
                run.isEmpty
                    ? S.hrNoPayrollRun
                    : '${payroll['period_year']}-${payroll['period_month']} · ${run['status']} · ${run['statement_count']}',
              ),
              trailing: run['total_net'] == null
                  ? null
                  : Text('${run['total_net']}'),
            ),
          ),
        ],
        if (cards.isEmpty && payroll.isEmpty && finance.isEmpty)
          Center(child: Text(S.hrDashboardNoMetrics)),
      ],
    );
  }

  Widget _metric(String label, Object? value, IconData icon) {
    if (value == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            AppIcon(icon, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label)),
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}
