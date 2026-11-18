import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_employee_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employee_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employee_state.dart';
import 'package:admin_app/features/hr/presentation/strings/hr_employee_strings.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_employment_edit_form.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

Future<bool?> showHrEmployeeFileDialog({
  required BuildContext context,
  required String staffId,
  required bool canWrite,
  HrEmployeeRepository? repository,
}) => showDialog<bool>(
  context: context,
  builder: (_) => HrEmployeeFileDialog(
    staffId: staffId,
    canWrite: canWrite,
    repository: repository,
  ),
);

class HrEmployeeFileDialog extends StatefulWidget {
  const HrEmployeeFileDialog({
    super.key,
    required this.staffId,
    required this.canWrite,
    this.repository,
    this.cubit,
  });

  final String staffId;
  final bool canWrite;
  final HrEmployeeRepository? repository;
  final HrEmployeeCubit? cubit;

  @override
  State<HrEmployeeFileDialog> createState() => _HrEmployeeFileDialogState();
}

class _HrEmployeeFileDialogState extends State<HrEmployeeFileDialog> {
  late final HrEmployeeCubit _cubit;
  late final bool _ownsCubit;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrEmployeeCubit(repository: widget.repository);
    _cubit.load(widget.staffId);
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_cubit.state.saved);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .88;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 940, maxHeight: height),
        child: BlocProvider<HrEmployeeCubit>.value(
          value: _cubit,
          child: BlocBuilder<HrEmployeeCubit, HrEmployeeState>(
            builder: (context, state) {
              final employee = state.employee;
              return Column(
                children: [
                  AdminDialogHeader(
                    title: employee?.fullName.isNotEmpty == true
                        ? employee!.fullName
                        : HrEmployeeStrings.fileTitle,
                    subtitle: employee?.email,
                    onClose: _close,
                  ),
                  Expanded(
                    child: switch (state.status) {
                      HrEmployeeStatus.initial ||
                      HrEmployeeStatus.loading => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: AppSpacing.md),
                            Text(HrEmployeeStrings.loading),
                          ],
                        ),
                      ),
                      HrEmployeeStatus.failure when employee == null =>
                        AdminFailureView(
                          message:
                              state.errorMessage ??
                              HrEmployeeStrings.loadFailed,
                          onRetry: () => _cubit.load(widget.staffId),
                        ),
                      _ when _editing && employee != null =>
                        HrEmploymentEditForm(
                          key: ValueKey('employment-${employee.staffId}'),
                          initial:
                              employee.employment ?? const HrEmploymentDraft(),
                          saving: state.status == HrEmployeeStatus.saving,
                          errorMessage: state.errorMessage,
                          onCancel: () => setState(() => _editing = false),
                          onSave: _cubit.saveEmployment,
                        ),
                      _ when employee != null => _EmployeeTabs(
                        employee: employee,
                        canWrite: widget.canWrite,
                        onEdit: () => setState(() => _editing = true),
                        errorMessage: state.errorMessage,
                      ),
                      _ => AdminFailureView(
                        message: HrEmployeeStrings.loadFailed,
                        onRetry: () => _cubit.load(widget.staffId),
                      ),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmployeeTabs extends StatelessWidget {
  const _EmployeeTabs({
    required this.employee,
    required this.canWrite,
    required this.onEdit,
    required this.errorMessage,
  });

  final HrEmployeeFile employee;
  final bool canWrite;
  final VoidCallback onEdit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: AdminInlineError(message: errorMessage!),
            ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColor.adminAccent,
            tabs: [
              Tab(text: HrEmployeeStrings.overview),
              Tab(text: HrEmployeeStrings.employment),
              Tab(text: HrEmployeeStrings.organization),
              Tab(text: HrEmployeeStrings.attendance),
              Tab(text: HrEmployeeStrings.leave),
              Tab(text: HrEmployeeStrings.payAndFinance),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _overview(employee),
                _employment(employee, canWrite, onEdit),
                _organization(employee, canWrite, onEdit),
                _records(employee.attendance, HrEmployeeStrings.attendance),
                _records(employee.leave, HrEmployeeStrings.leave),
                _payAndFinance(employee),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _overview(HrEmployeeFile employee) => ListView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  children: [
    _section(HrEmployeeStrings.overview, [
      _item(HrEmployeeStrings.fullName, employee.fullName),
      _item(HrEmployeeStrings.email, employee.email),
      _item(
        HrEmployeeStrings.accountStatus,
        _accountStatus(employee.accountStatus),
      ),
      _item(
        HrEmployeeStrings.employmentStatus,
        _employmentStatus(employee.employment?.employmentStatus),
      ),
      _item(
        HrEmployeeStrings.employeeNumber,
        employee.employment?.employeeNumber,
      ),
      _item(HrEmployeeStrings.department, employee.employment?.department),
      _item(HrEmployeeStrings.jobTitle, employee.employment?.jobTitle),
    ]),
  ],
);

Widget _employment(
  HrEmployeeFile employee,
  bool canWrite,
  VoidCallback onEdit,
) => ListView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  children: [
    _section(HrEmployeeStrings.employment, [
      _item(
        HrEmployeeStrings.employeeNumber,
        employee.employment?.employeeNumber,
      ),
      _item(
        HrEmployeeStrings.employmentType,
        _employmentType(employee.employment?.employmentType),
      ),
      _item(
        HrEmployeeStrings.employmentStatus,
        _employmentStatus(employee.employment?.employmentStatus),
      ),
      _item(HrEmployeeStrings.hireDate, _date(employee.employment?.hiredOn)),
      _item(
        HrEmployeeStrings.terminationDate,
        _date(employee.employment?.terminatedOn),
      ),
      _item(HrEmployeeStrings.phone, employee.employment?.phone),
      _item(
        HrEmployeeStrings.emergencyName,
        employee.employment?.emergencyContactName,
      ),
      _item(
        HrEmployeeStrings.emergencyPhone,
        employee.employment?.emergencyContactPhone,
      ),
      _item(HrEmployeeStrings.notes, employee.employment?.notes),
    ]),
    if (canWrite) ...[
      const SizedBox(height: AppSpacing.md),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.icon(
          key: const Key('hr-employment-edit'),
          onPressed: onEdit,
          icon: const AppIcon(AppIcons.edit01, size: 16),
          label: Text(HrEmployeeStrings.editEmployment),
        ),
      ),
    ],
  ],
);

Widget _organization(
  HrEmployeeFile employee,
  bool canWrite,
  VoidCallback onEdit,
) => ListView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  children: [
    _section(HrEmployeeStrings.organization, [
      _item(HrEmployeeStrings.department, employee.employment?.department),
      _item(HrEmployeeStrings.jobTitle, employee.employment?.jobTitle),
      _item(
        HrEmployeeStrings.branches,
        employee.branches.isEmpty
            ? null
            : employee.branches.map(_localizedName).join(_separator),
      ),
      _item(
        HrEmployeeStrings.roles,
        employee.roles.isEmpty
            ? null
            : employee.roles.map(_localizedName).join(_separator),
      ),
    ]),
    if (canWrite) ...[
      const SizedBox(height: AppSpacing.md),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          onPressed: onEdit,
          icon: const AppIcon(AppIcons.edit01, size: 16),
          label: Text(HrEmployeeStrings.editEmployment),
        ),
      ),
    ],
  ],
);

Widget _records(List<HrJson>? rows, String title) {
  if (rows == null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(HrEmployeeStrings.restricted, textAlign: TextAlign.center),
      ),
    );
  }
  if (rows.isEmpty) {
    return Center(child: Text(HrEmployeeStrings.noRows));
  }
  return ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.lg),
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, index) => _dataCard(rows[index], title),
  );
}

Widget _payAndFinance(HrEmployeeFile employee) => ListView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  children: [
    _section(HrEmployeeStrings.salary, [
      if (employee.compensation == null)
        _item(HrEmployeeStrings.salary, HrEmployeeStrings.restricted)
      else ...[
        _item(
          HrEmployeeStrings.salary,
          _money(
            employee.compensation!['current'] is Map
                ? (employee.compensation!['current'] as Map)['basic_salary']
                : null,
          ),
        ),
        _item(
          HrEmployeeStrings.effectiveFrom,
          employee.compensation!['current'] is Map
              ? '${(employee.compensation!['current'] as Map)['effective_from'] ?? ''}'
              : null,
        ),
      ],
    ]),
    const SizedBox(height: AppSpacing.md),
    _recordSection(HrEmployeeStrings.payAndFinance, employee.payslips, [
      HrEmployeeStrings.date,
      HrEmployeeStrings.gross,
      HrEmployeeStrings.deductions,
      HrEmployeeStrings.net,
    ]),
    const SizedBox(height: AppSpacing.md),
    _recordSection(HrEmployeeStrings.payAndFinance, employee.advances, [
      HrEmployeeStrings.amount,
      HrEmployeeStrings.outstanding,
      HrEmployeeStrings.status,
      HrEmployeeStrings.reason,
    ]),
    const SizedBox(height: AppSpacing.md),
    _recordSection(HrEmployeeStrings.payAndFinance, employee.adjustments, [
      HrEmployeeStrings.date,
      HrEmployeeStrings.amount,
      HrEmployeeStrings.status,
      HrEmployeeStrings.reason,
    ]),
    const SizedBox(height: AppSpacing.md),
    _recordSection(HrEmployeeStrings.payAndFinance, employee.cashierShifts, [
      HrEmployeeStrings.status,
      HrEmployeeStrings.date,
      HrEmployeeStrings.amount,
    ]),
  ],
);

Widget _recordSection(String title, List<HrJson>? rows, List<String> labels) {
  if (rows == null) {
    return _section(title, [_item(title, HrEmployeeStrings.restricted)]);
  }
  if (rows.isEmpty) {
    return _section(title, [_item(title, HrEmployeeStrings.noRows)]);
  }
  return _section(title, [
    for (final row in rows) _dataCard(row, title, labels),
  ]);
}

Widget _dataCard(HrJson row, String title, [List<String> labels = const []]) {
  final pairs = <(String, Object?)>[];
  if (title == HrEmployeeStrings.attendance) {
    pairs.addAll(<(String, Object?)>[
      (HrEmployeeStrings.branches, _localizedName(row)),
      (HrEmployeeStrings.date, row['clock_in_local'] ?? row['clock_in']),
      (
        HrEmployeeStrings.status,
        row['is_open'] == true
            ? HrEmployeeStrings.active
            : row['clock_out_local'] ?? row['clock_out'],
      ),
    ]);
  } else if (title == HrEmployeeStrings.leave) {
    pairs.addAll(<(String, Object?)>[
      (
        HrEmployeeStrings.date,
        '${row['starts_on'] ?? ''} – ${row['ends_on'] ?? ''}',
      ),
      (HrEmployeeStrings.status, row['status']),
      (HrEmployeeStrings.reason, row['reason']),
    ]);
  } else {
    final rawKeys = <String>[
      'period_year',
      'period_month',
      'gross',
      'deductions_total',
      'net',
      'amount',
      'outstanding',
      'status',
      'reason',
      'kind',
      'effective_date',
      'variance',
    ];
    final valueLabels = labels.isEmpty
        ? <String, String>{
            'amount': HrEmployeeStrings.amount,
            'outstanding': HrEmployeeStrings.outstanding,
            'status': HrEmployeeStrings.status,
            'reason': HrEmployeeStrings.reason,
            'kind': HrEmployeeStrings.code,
            'effective_date': HrEmployeeStrings.date,
            'variance': HrEmployeeStrings.amount,
          }
        : <String, String>{
            'period_year': HrEmployeeStrings.date,
            'period_month': HrEmployeeStrings.date,
            'gross': HrEmployeeStrings.gross,
            'deductions_total': HrEmployeeStrings.deductions,
            'net': HrEmployeeStrings.net,
            'amount': HrEmployeeStrings.amount,
            'outstanding': HrEmployeeStrings.outstanding,
            'status': HrEmployeeStrings.status,
            'reason': HrEmployeeStrings.reason,
            'kind': HrEmployeeStrings.code,
            'effective_date': HrEmployeeStrings.date,
            'variance': HrEmployeeStrings.amount,
          };
    for (final key in rawKeys) {
      if (row[key] != null) pairs.add((valueLabels[key] ?? key, row[key]));
    }
  }
  return _section(title, [for (final pair in pairs) _item(pair.$1, pair.$2)]);
}

Widget _section(String title, List<Widget> children) => Card(
  margin: EdgeInsets.zero,
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppFontSizes.size12,
            fontWeight: AppFontWeights.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final child in children) child,
      ],
    ),
  ),
);

Widget _item(String label, Object? value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 180,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColor.adminDate,
            fontSize: AppFontSizes.size10_5,
          ),
        ),
      ),
      Expanded(
        child: Text(
          _display(value),
          style: const TextStyle(fontSize: AppFontSizes.size10_5),
        ),
      ),
    ],
  ),
);

String _display(Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? HrEmployeeStrings.noValue : text;
}

String _localizedName(Map row) {
  final key = AppLocale.instance.isArabic ? 'name_ar' : 'name_en';
  return '${row[key] ?? row['code'] ?? ''}';
}

String get _separator => AppLocale.instance.isArabic ? '، ' : ', ';

String _date(DateTime? value) => value == null
    ? ''
    : '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';

String _accountStatus(String value) => switch (value) {
  'active' => HrEmployeeStrings.active,
  'invited' => AppLocale.instance.isArabic ? 'بانتظار التفعيل' : 'Invited',
  'suspended' => AppLocale.instance.isArabic ? 'موقوف' : 'Suspended',
  _ => _display(value),
};

String? _employmentStatus(String? value) => switch (value) {
  'active' => HrEmployeeStrings.active,
  'probation' => HrEmployeeStrings.probation,
  'on_leave' => HrEmployeeStrings.onLeave,
  'terminated' => HrEmployeeStrings.terminated,
  _ => value,
};

String? _employmentType(String? value) => switch (value) {
  'full_time' => HrEmployeeStrings.fullTime,
  'part_time' => HrEmployeeStrings.partTime,
  'contract' => HrEmployeeStrings.contract,
  _ => value,
};

String _money(Object? value) =>
    value == null ? HrEmployeeStrings.noValue : '$value SAR';
