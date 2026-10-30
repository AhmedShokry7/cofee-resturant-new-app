import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';

/// حالة المرجع الواحد الذي تبني عليه شاشات HR قوائمها: الفروع وأنواع الإجازة
/// والأقسام وسياسة العمل، ثم دليل الموظفين لترشيحات الحوارات.
class HrReferenceState {
  const HrReferenceState({
    this.status = HrLoadStatus.initial,
    this.reference,
    this.failure,
    this.writing = HrWriteStatus.idle,
    this.receipt,
    this.people,
    this.peopleFailure,
  });

  final HrLoadStatus status;

  /// `null` قبل أن يعود المرجع: فرعٌ لم يُقرأ ليس قائمة فارغة.
  final HrReference? reference;

  final HrRefusal? failure;
  final HrWriteStatus writing;

  /// إيصال آخر كتابة على سياسة أو نوع إجازة.
  final HrReceipt? receipt;

  /// مرشَّحو الحوارات من `admin_hr_employees`. `null` أن الدليل لم يُقرأ أو
  /// رُفض — و`[]` أنه قرئ ولا موظف في النطاق؛ سؤالان مختلفان عند من ينشئ جدولًا.
  final List<HrPersonOption>? people;

  /// رفض قراءة الدليل وحده: مرجع مقروء مع دليل مرفوض حالةٌ قائمة بذاتها.
  final HrRefusal? peopleFailure;

  bool get isLoading => status == HrLoadStatus.loading;
  bool get isWriting => writing == HrWriteStatus.sending;

  HrReferenceState copyWith({
    HrLoadStatus? status,
    HrReference? reference,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
    HrReceipt? receipt,
    List<HrPersonOption>? people,
    HrRefusal? peopleFailure,
    bool clearPeopleFailure = false,
  }) => HrReferenceState(
    status: status ?? this.status,
    reference: reference ?? this.reference,
    failure: clearFailure ? null : (failure ?? this.failure),
    writing: writing ?? this.writing,
    receipt: receipt ?? this.receipt,
    people: people ?? this.people,
    peopleFailure: clearPeopleFailure
        ? null
        : (peopleFailure ?? this.peopleFailure),
  );
}
