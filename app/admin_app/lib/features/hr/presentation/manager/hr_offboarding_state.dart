import 'package:admin_app/features/hr/domain/entities/hr_offboarding.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة إنهاء الخدمة على ملف موظف واحد.
class HrOffboardingState {
  const HrOffboardingState({
    this.status = HrLoadStatus.initial,
    this.cases = const <HrOffboardingCase>[],
    this.failure,
    this.writing = HrWriteStatus.idle,
  });

  final HrLoadStatus status;
  final List<HrOffboardingCase> cases;

  /// رفض القاعدة كما قالته، يُعرض في اللوحة لا خلفها.
  final HrRefusal? failure;
  final HrWriteStatus writing;

  bool get isWriting => writing == HrWriteStatus.sending;

  HrOffboardingState copyWith({
    HrLoadStatus? status,
    List<HrOffboardingCase>? cases,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
  }) => HrOffboardingState(
        status: status ?? this.status,
        cases: cases ?? this.cases,
        failure: clearFailure ? null : (failure ?? this.failure),
        writing: writing ?? this.writing,
      );
}
