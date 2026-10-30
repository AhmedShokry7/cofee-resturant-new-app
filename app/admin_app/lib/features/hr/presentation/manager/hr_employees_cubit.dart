import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_employees_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// الأدلة الوظيفية: من يعمل أين، وما عقده، وملفه حين يُفتح.
///
/// الحفظ يكتب سجل التوظيف فقط؛ الهويّة والحساب وصلاحية الدخول تبقى في يد
/// `staff` و`roles`، فلا تفتح هذه الشاشة حسابًا ولا تمنح صلاحية.
class HrEmployeesCubit extends Cubit<HrEmployeesState> {
  HrEmployeesCubit({HrPeopleRepository? repository, HrPayrollRepository? pay})
    : _repository = repository ?? HrDependencies.people,
      _payroll = pay ?? HrDependencies.payroll,
      super(const HrEmployeesState());

  final HrPeopleRepository _repository;

  /// تركيبة الأجر عقدٌ في عقد الرواتب (`hr.compensation.manage`)، وهي تُكتب من
  /// ملف الموظف؛ فالأداة هنا وصلٌ إليها لا نسخة من قواعدها.
  final HrPayrollRepository _payroll;

  String search = '';
  String? status;
  String? branchId;
  String? department;

  Future<void> setFilters({
    String? newSearch,
    String? newStatus,
    String? newBranchId,
    String? newDepartment,
  }) async {
    if (newSearch != null) search = newSearch;
    status = newStatus;
    branchId = newBranchId;
    department = newDepartment;
    await reload();
  }

  Future<void> reload() async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          employees: await _repository.loadEmployees(
            search: search.isEmpty ? null : search,
            status: status,
            branchId: branchId,
            department: department,
          ),
          clearFailure: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: HrLoadStatus.failure,
          failure: hrRefusalOf(error),
        ),
      );
    }
  }

  Future<void> openFile(String staffId) async {
    emit(state.copyWith(clearFailure: true));
    try {
      emit(state.copyWith(file: await _repository.loadEmployeeFile(staffId)));
    } catch (error) {
      emit(state.copyWith(clearFile: true, failure: hrRefusalOf(error)));
    }
  }

  void closeFile() => emit(state.copyWith(clearFile: true));

  Future<bool> saveEmployment({
    required String staffId,
    String? employeeNumber,
    String? department,
    String? jobTitle,
    String? employmentType,
    String? employmentStatus,
    DateTime? hiredOn,
    DateTime? terminatedOn,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? notes,
  }) async {
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    try {
      // الحفظ يرجع سجل التوظيف نفسه، لا إيصالًا: لا رقم يُخترع لسطر لم يردّ
      // عليه أحد، والسجل يُقرأ من جديد مع الملف والقائمة.
      await _repository.saveEmployment(
        staffId: staffId,
        employeeNumber: employeeNumber,
        department: department,
        jobTitle: jobTitle,
        employmentType: employmentType,
        employmentStatus: employmentStatus,
        hiredOn: hiredOn,
        terminatedOn: terminatedOn,
        phone: phone,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        notes: notes,
      );
      emit(state.copyWith(writing: HrWriteStatus.done, clearFailure: true));
      // الملف المفتوح وحده يُعاد قراءته: الحالة والاسم قد يتغيّران بعد الحفظ،
      // وأما الحفظ من القائمة فلا يفتح ملفًا لم يفتحه أحد.
      if (state.file?.employee.staffId == staffId) {
        emit(state.copyWith(file: await _repository.loadEmployeeFile(staffId)));
      }
      await reload();
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          writing: HrWriteStatus.done,
          failure: hrRefusalOf(error),
        ),
      );
      return false;
    }
  }

  /// تركيبة أجر جديدة لموظف من ملفه المفتوح.
  ///
  /// السطر في الدليل لا يتغيّر براتب، فلا تُكلَّف القاعدة بسؤال ثان: الملف وحده
  /// يُعاد قراءته لأن 212 ترجع التركيبة الحالية من داخله.
  Future<bool> setCompensation({
    required String staffId,
    required double basicSalary,
    double housingAllowance = 0,
    double transportAllowance = 0,
    double otherAllowance = 0,
    DateTime? effectiveFrom,
    String? note,
  }) async {
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    try {
      await _payroll.setCompensation(
        staffId: staffId,
        basicSalary: basicSalary,
        housingAllowance: housingAllowance,
        transportAllowance: transportAllowance,
        otherAllowance: otherAllowance,
        effectiveFrom: effectiveFrom,
        note: note,
      );
      emit(state.copyWith(writing: HrWriteStatus.done, clearFailure: true));
      if (state.file?.employee.staffId == staffId) {
        emit(state.copyWith(file: await _repository.loadEmployeeFile(staffId)));
      }
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          writing: HrWriteStatus.done,
          failure: hrRefusalOf(error),
        ),
      );
      return false;
    }
  }
}
