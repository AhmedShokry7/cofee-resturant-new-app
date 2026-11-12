import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employees_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_offboarding_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employees_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_compensation_form_dialog.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_employee_file_sheet.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_offboarding_panel.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_employees_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_employment_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة الملفات الوظيفية: الدليل، وملف واحد مفتوح فوقه، وكتابة سجل الارتباط.
///
/// الملف لا يفتحه إلا من قرأه: الأقسام المحجوبة تبقى محجوبة بحرف القاعدة.
/// والكتابة تُرسل بعد الحوار لا قبله، لأن الحفظ يكتب السجل كاملًا فلا تُرسل
/// شاشةٌ قيمةً لم ترَها في الملف المفتوح.
class HrEmployeesPage extends StatefulWidget {
  const HrEmployeesPage({
    super.key,
    required this.searchController,
    required this.canManage,
    required this.canManageCompensation,
    this.cubit,
    this.reference,
  });

  final AdminSearchController searchController;

  /// من يملك كتابة التوظيف: يراه الحوار، وأما السطور فتبقى مرئية للجميع.
  final bool canManage;

  /// `hr.compensation.manage`، وهي في 212 غير `hr.employee.write`: مدير الفريق
  /// يعدّل العقد وقد لا يمسّ الأجر، ومَن يملك الأجر قد لا يعدّل العقد.
  final bool canManageCompensation;
  final HrEmployeesCubit? cubit;
  final HrReferenceCubit? reference;

  @override
  State<HrEmployeesPage> createState() => _HrEmployeesPageState();
}

class _HrEmployeesPageState extends State<HrEmployeesPage> {
  late final HrEmployeesCubit _cubit;
  late final HrReferenceCubit _reference;
  late final HrOffboardingCubit _offboarding;
  late final bool _ownsCubit;
  String _search = '';
  String? _offboardingStaffId;
  String? _offboardingStaffName;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrEmployeesCubit();
    _reference = widget.reference ?? HrReferenceCubit();
    _offboarding = HrOffboardingCubit();
    if (_ownsCubit) {
      _cubit.reload();
      _reference.load();
    }
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) {
      _cubit.close();
      _reference.close();
    }
    _offboarding.close();
    super.dispose();
  }

  /// البحث يصفّي ما قرأه الدليل في الجدول نفسه، كبقية أسطح HR.
  void _onSearch(String query) => setState(() => _search = query.trim());

  /// `setFilters` يكتب المرشحات الثلاثة في كل مرة، فيُعاد معها ما لم يتغيّر:
  /// وإلا صار اختيار فرع وحده مسحًا لحالة الارتباط التي اختارها المدير.
  Future<void> _setStatus(String? value) => _cubit.setFilters(
    newStatus: value,
    newBranchId: _cubit.branchId,
    newDepartment: _cubit.department,
  );

  Future<void> _setBranch(String? value) => _cubit.setFilters(
    newStatus: _cubit.status,
    newBranchId: value,
    newDepartment: _cubit.department,
  );

  Future<void> _setDepartment(String? value) => _cubit.setFilters(
    newStatus: _cubit.status,
    newBranchId: _cubit.branchId,
    newDepartment: value,
  );

  Future<void> _edit(HrEmployee employee) async {
    final draft = await showHrEmploymentFormDialog(
      context,
      employee: employee,
      departments: _reference.state.reference?.departments ?? const <String>[],
    );
    if (draft == null) return;
    await _cubit.saveEmployment(
      staffId: draft.staffId,
      employeeNumber: draft.employeeNumber,
      department: draft.department,
      jobTitle: draft.jobTitle,
      employmentType: draft.employmentType,
      employmentStatus: draft.employmentStatus,
      hiredOn: draft.hiredOn,
      terminatedOn: draft.terminatedOn,
      phone: draft.phone,
      emergencyContactName: draft.emergencyContactName,
      emergencyContactPhone: draft.emergencyContactPhone,
      notes: draft.notes,
    );
  }

  /// تركيبة الأجر تُكتب للموظف المفتوح وحده: القائمة لا تختار شخصًا من ورائه،
  /// ومن لا يقرأ أجره لا يحرّره.
  Future<void> _setCompensation(HrEmployeeFile file) async {
    final draft = await showHrCompensationFormDialog(
      context,
      people: <HrPersonOption>[
        HrPersonOption(
          file.employee.staffId,
          hrPersonName(file.employee.fullName),
        ),
      ],
    );
    if (draft == null) return;
    await _cubit.setCompensation(
      staffId: draft.staffId,
      basicSalary: draft.basicSalary,
      housingAllowance: draft.housingAllowance,
      transportAllowance: draft.transportAllowance,
      otherAllowance: draft.otherAllowance,
      effectiveFrom: draft.effectiveFrom,
      note: draft.note,
    );
  }

  /// لوحة إنهاء الخدمة تفتح من الملف لمن يملك الكتابة، فوق الغطاء لا داخله.
  void _openOffboarding(HrEmployee employee) {
    setState(() {
      _offboardingStaffId = employee.staffId;
      _offboardingStaffName = employee.fullName;
    });
    _offboarding.load(employee.staffId);
  }

  void _closeOffboarding() {
    setState(() {
      _offboardingStaffId = null;
      _offboardingStaffName = null;
    });
    _cubit.reload();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HrEmployeesCubit>.value(value: _cubit),
        BlocProvider<HrReferenceCubit>.value(value: _reference),
      ],
      child: BlocBuilder<HrReferenceCubit, HrReferenceState>(
        builder: (context, reference) =>
            BlocBuilder<HrEmployeesCubit, HrEmployeesState>(
              builder: (context, state) => _body(context, state, reference),
            ),
      ),
    );
  }

  /// الدليل، وفوقه الملف المفتوح حين يكون واحدًا مفتوحًا.
  Widget _body(
    BuildContext context,
    HrEmployeesState state,
    HrReferenceState reference,
  ) {
    final directory = HrEmployeesView(
      state: state,
      reference: reference.reference,
      search: _search,
      status: _cubit.status,
      branchId: _cubit.branchId,
      department: _cubit.department,
      onStatusChanged: _setStatus,
      onBranchChanged: _setBranch,
      onDepartmentChanged: _setDepartment,
      onOpenFile: _cubit.openFile,
      onRetry: _cubit.reload,
    );
    final file = state.file;
    if (file == null) return directory;
    // الحفظ يحدّث الملف نفسه في العقدة، فلا تعيد الصفحة قراءته من هنا.
    return Stack(
      fit: StackFit.expand,
      children: [directory, _overlay(context, file, state)],
    );
  }

  /// غطاء فوق الدليل: لمسة خارجه تُغلق الملف، والكتابة تمرّ لمن يملكها.
  Widget _overlay(
    BuildContext context,
    HrEmployeeFile file,
    HrEmployeesState state,
  ) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _cubit.closeFile,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: theme.colorScheme.scrim.withValues(alpha: .45),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: HrEmployeeFileSheet(
              file: file,
              onClose: _cubit.closeFile,
              onEdit: widget.canManage ? () => _edit(file.employee) : null,
              onEditCompensation: widget.canManageCompensation
                  ? () => _setCompensation(file)
                  : null,
              onOpenOffboarding: widget.canManage
                  ? () => _openOffboarding(file.employee)
                  : null,
              // الرفض بعد الكتابة يظهر داخل الغطاء: الدليل خلفه لا يُقرأ.
              refusal: state.failure,
            ),
          ),
          if (_offboardingStaffId != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeOffboarding,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: theme.colorScheme.scrim.withValues(alpha: .45),
                ),
              ),
            ),
          if (_offboardingStaffId != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimensions.dialogBodyWidthExtra,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: adminCardBorderColor(theme)),
                    ),
                    child: HrOffboardingPanel(
                      staffId: _offboardingStaffId!,
                      staffName: _offboardingStaffName ?? '',
                      cubit: _offboarding,
                      onClose: _closeOffboarding,
                      people: _reference.state.people ?? const <HrPersonOption>[],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
