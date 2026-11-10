import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employees_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_value_segment.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:flutter/material.dart';

/// دليل الملفات الوظيفية: من يعمل أين، وبأي عقد، وعلى أي الفروع.
///
/// حالة الدليل `HrEmployeesState` لا `HrListState`، فالقطعة تُركّب من عناصر
/// `HrPageScaffold` نفسها: قراءة فاشلة تُعرض رفضًا لا قائمة فارغة، والترشيح
/// يرسل للقاعدة لأن الفروع والأقسام تعرفها هي وحدها لا الشاشة.
class HrEmployeesView extends StatelessWidget {
  const HrEmployeesView({
    super.key,
    required this.state,
    required this.reference,
    required this.search,
    required this.status,
    required this.branchId,
    required this.department,
    required this.onStatusChanged,
    required this.onBranchChanged,
    required this.onDepartmentChanged,
    required this.onOpenFile,
    required this.onRetry,
  });

  final HrEmployeesState state;

  /// المرجع كما قرأته القاعدة: `null` يعني أن قوائم الترشيح لم تُقرأ بعد،
  /// فلا تُعرض قطعتا الفرع والقسم كقائمتين فارغتين.
  final HrReference? reference;
  final String search;

  /// المرشحات المرسلة للقاعدة كما هي مخزنة في العقدة، و`null` = بلا ترشيح.
  final String? status;
  final String? branchId;
  final String? department;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String> onOpenFile;
  final VoidCallback onRetry;

  /// حالات الارتباط التي يقيّدها CHECK في 212، بترتيب عرضها.
  static const List<String> _statuses = <String>[
    'active',
    'probation',
    'on_leave',
    'terminated',
  ];

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.hrEmployees,
            subtitle: S.hrEmployeesSubtitle,
            progress: state.isWriting || state.isLoading ? 0 : null,
            progressLabel: state.isWriting ? S.saving : null,
          ),
          HrRefusalNote(refusal: failure),
          if (state.receipt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            HrReceiptNote(receipt: state.receipt!),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _body(context, failure)),
        ],
      ),
    );
  }

  /// ترشيحات الدليل: حالة الارتباط دائمًا، والفرع والقسم مما قرأه المرجع.
  Widget _filters(BuildContext context) {
    final branches = reference?.branches ?? const <HrBranch>[];
    final departments = reference?.departments ?? const <String>[];
    return HrFilterStrip(
      children: [
        HrValueSegment(
          label: S.hrFilterStatus,
          allLabel: S.hrFilterAll,
          choices: [
            for (final value in _statuses)
              HrFilterChoice(value, hrStatusLabel(value).text),
          ],
          selected: status,
          onChanged: onStatusChanged,
        ),
        if (branches.isNotEmpty)
          HrValueSegment(
            label: S.hrColBranch,
            allLabel: S.hrFilterAllBranches,
            choices: [
              for (final branch in branches)
                HrFilterChoice(branch.id, hrBranchName(branch)),
            ],
            selected: branchId,
            onChanged: onBranchChanged,
          ),
        if (departments.isNotEmpty)
          HrValueSegment(
            label: S.hrColDepartment,
            allLabel: S.hrFilterAllDepartments,
            choices: [
              for (final value in departments) HrFilterChoice(value, value),
            ],
            selected: department,
            onChanged: onDepartmentChanged,
          ),
      ],
    );
  }

  Widget _body(BuildContext context, HrRefusal? failure) {
    if (state.isLoading && state.employees.isEmpty) {
      return const AdminLoadingView();
    }
    if (state.status == HrLoadStatus.failure && state.employees.isEmpty) {
      return AdminFailureView(
        message: failure == null ? null : hrRefusalMessage(failure),
        onRetry: onRetry,
      );
    }
    return AdminDirectoryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(context),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: HrDirectory<HrEmployee>(
              items: state.employees,
              columns: <String>[
                S.hrColEmployee,
                S.hrColEmployeeNumber,
                S.hrColJobTitle,
                S.hrColDepartment,
                S.status,
                S.hrAccountStatus,
                S.hrColBranch,
              ],
              cellsOf: (context, employee) => [
                _identityCell(employee),
                HrCellText(employee.employment.employeeNumber),
                HrCellText(employee.employment.jobTitle),
                HrCellText(employee.employment.department),
                HrStatusCell(employee.employment.employmentStatus),
                HrStatusCell(employee.accountStatus),
                HrCellText(
                  employee.branches.isEmpty
                      ? S.hrNoBranch
                      : employee.branches.join(' · '),
                ),
              ],
              cardOf: (context, employee) => _card(context, employee),
              actionsOf: (context, employee) => [
                HrRowButton(
                  text: S.hrBtnOpenFile,
                  onPressed: () => onOpenFile(employee.staffId),
                ),
              ],
              searchOf: (employee) =>
                  '${employee.fullName} ${employee.email} '
                  '${employee.employment.employeeNumber} '
                  '${employee.employment.jobTitle} ${employee.employment.department}',
              search: search,
              emptyLabel: S.hrEmptyEmployees,
              emptyHint: S.hrEmptyFilterHint,
              emptyIcon: AppIcons.userMultiple,
              onTap: (employee) => onOpenFile(employee.staffId),
              pageSize: state.employees.isEmpty ? 20 : state.employees.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCell(HrEmployee employee) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HrCellText(hrPersonName(employee.fullName), strong: true),
      if (employee.email.isNotEmpty) HrCellText(employee.email, muted: true),
    ],
  );

  /// بطاقة السطر على الشاشة الضيقة: العقد والتعيين والفروع التي يغطيها.
  ///
  /// البطاقة تُفتح باللمسة كما يفتح السطر في الجدول، وإلا كان ملف الموظف —
  /// وكل كتابة منه — unreachable على الهاتف وحده.
  Widget _card(BuildContext context, HrEmployee employee) {
    final job = employee.employment;
    return HrRecordCard(
      title: hrPersonName(employee.fullName),
      subtitle: employee.email.isNotEmpty
          ? employee.email
          : (job.jobTitle.isEmpty ? null : job.jobTitle),
      badge: HrStatusCell(job.employmentStatus),
      onTap: () => onOpenFile(employee.staffId),
      fields: [
        HrCardField(S.hrColEmployeeNumber, HrCellText(job.employeeNumber)),
        if (job.jobTitle.isNotEmpty)
          HrCardField(S.hrColJobTitle, HrCellText(job.jobTitle)),
        HrCardField(S.hrColDepartment, HrCellText(job.department)),
        HrCardField(S.hrAccountStatus, HrStatusCell(employee.accountStatus)),
        HrCardField(
          S.hrFieldEmploymentType,
          HrCellText(hrEmploymentTypeLabel(job.employmentType)),
        ),
        HrCardField(S.hrColHiredOn, HrCellText(localizedDate(job.hiredOn))),
        HrCardField(
          S.hrColBranch,
          HrCellText(
            employee.branches.isEmpty
                ? S.hrNoBranch
                : employee.branches.join(' · '),
          ),
        ),
      ],
      trailing: HrRowButton(
        text: S.hrBtnOpenFile,
        onPressed: () => onOpenFile(employee.staffId),
      ),
    );
  }
}
