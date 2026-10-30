import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة الملفات الوظيفية: قائمة واحدة، وملف واحد مفتوح عند الطلب.
class HrEmployeesState {
  const HrEmployeesState({
    this.status = HrLoadStatus.initial,
    this.employees = const <HrEmployee>[],
    this.file,
    this.failure,
    this.writing = HrWriteStatus.idle,
    this.receipt,
  });

  final HrLoadStatus status;
  final List<HrEmployee> employees;

  /// الملف المفتوح: `null` ما لم يُفتح، ومحتواه الذي لا يملك المدير رؤيته
  /// يبقى `null` من القاعدة نفسها لا تحذفه الشاشة.
  final HrEmployeeFile? file;

  final HrRefusal? failure;
  final HrWriteStatus writing;

  /// إيصال آخر حفظ: رقم السطر وحالته، فبقية الحقول تُقرأ من الملف لا منه.
  final HrReceipt? receipt;

  bool get isLoading => status == HrLoadStatus.loading;
  bool get isWriting => writing == HrWriteStatus.sending;

  HrEmployeesState copyWith({
    HrLoadStatus? status,
    List<HrEmployee>? employees,
    HrEmployeeFile? file,
    bool clearFile = false,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
    HrReceipt? receipt,
  }) => HrEmployeesState(
    status: status ?? this.status,
    employees: employees ?? this.employees,
    file: clearFile ? null : (file ?? this.file),
    failure: clearFailure ? null : (failure ?? this.failure),
    writing: writing ?? this.writing,
    receipt: receipt ?? this.receipt,
  );
}
