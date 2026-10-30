import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employees_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_filter_scroll.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
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
            progress: state.isWriting ? 0 : null,
            progressLabel: state.isWriting ? S.saving : null,
          ),
          HrRefusalNote(refusal: failure),
          if (state.receipt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            HrReceiptNote(receipt: state.receipt!),
          ],
          const SizedBox(height: AppSpacing.sm),
          _filters(context),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _body(failure)),
        ],
      ),
    );
  }

  /// ترشيحات الدليل: حالة الارتباط دائمًا، والفرع والقسم مما قرأه المرجع.
  Widget _filters(BuildContext context) {
    final branches = [
      for (final branch in reference?.branches ?? const <HrBranch>[])
        hrBranchName(branch),
    ];
    final departments = reference?.departments ?? const <String>[];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _control(
          <String>[
            S.hrFilterAll,
            for (final s in _statuses) hrStatusLabel(s).text,
          ],
          status == null ? 0 : _statuses.indexOf(status!) + 1,
          (index) => onStatusChanged(index == 0 ? null : _statuses[index - 1]),
        ),
        if (branches.isNotEmpty)
          _control(
            <String>[S.hrFilterAllBranches, ...branches],
            branches.indexOf(branchId ?? '') + 1,
            (index) => onBranchChanged(index == 0 ? null : branches[index - 1]),
          ),
        if (departments.isNotEmpty)
          _control(
            <String>[S.hrFilterAllDepartments, ...departments],
            departments.indexOf(department ?? '') + 1,
            (index) =>
                onDepartmentChanged(index == 0 ? null : departments[index - 1]),
          ),
      ],
    );
  }

  /// شريط ترشيح يُمرَّر أفقيًا على الشاشة الضيقة بدل أن ينكسر سطرين.
  Widget _control(
    List<String> labels,
    int selected,
    ValueChanged<int> onPicked,
  ) => HrFilterScroll(
    control: AdminSegmentedControl(
      options: labels,
      selected: labels[selected.clamp(0, labels.length - 1)],
      onChanged: (label) => onPicked(labels.indexOf(label)),
    ),
  );

  Widget _body(HrRefusal? failure) {
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
      child: HrDirectory<HrEmployee>(
        items: state.employees,
        columns: <String>[
          S.hrColEmployee,
          S.hrColEmployeeNumber,
          S.hrColJobTitle,
          S.hrColDepartment,
          S.status,
          S.hrColBranch,
        ],
        cellsOf: (context, employee) => [
          HrCellText(hrPersonName(employee.fullName), strong: true),
          HrCellText(employee.employment.employeeNumber),
          HrCellText(employee.employment.jobTitle),
          HrCellText(employee.employment.department),
          HrStatusCell(employee.employment.employmentStatus),
          HrCellText(
            employee.branches.isEmpty
                ? S.hrNoBranch
                : employee.branches.join(' · '),
          ),
        ],
        cardOf: (context, employee) => _card(context, employee),
        searchOf: (employee) =>
            '${employee.fullName} ${employee.employment.employeeNumber} '
            '${employee.employment.jobTitle} ${employee.employment.department}',
        search: search,
        emptyLabel: S.hrEmptyEmployees,
        onTap: (employee) => onOpenFile(employee.staffId),
      ),
    );
  }

  /// بطاقة السطر على الشاشة الضيقة: العقد والتعيين والفروع التي يغطيها.
  ///
  /// البطاقة تُفتح باللمسة كما يفتح السطر في الجدول، وإلا كان ملف الموظف —
  /// وكل كتابة منه — unreachable على الهاتف وحده.
  Widget _card(BuildContext context, HrEmployee employee) {
    final job = employee.employment;
    return HrRecordCard(
      title: hrPersonName(employee.fullName),
      subtitle: job.jobTitle.isEmpty ? null : job.jobTitle,
      badge: HrStatusCell(job.employmentStatus),
      onTap: () => onOpenFile(employee.staffId),
      fields: [
        HrCardField(S.hrColEmployeeNumber, HrCellText(job.employeeNumber)),
        HrCardField(S.hrColDepartment, HrCellText(job.department)),
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
    );
  }
}
