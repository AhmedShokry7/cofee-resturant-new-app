import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// حالة إنهاء خدمة كما تردّها `admin_hr_offboarding_cases` و
/// `hr.offboarding_case_json`: قائمة خطوات ثابتة، لكل خطوة مالكها وملاحظتها
/// ومنفّذها — لا معادلات مستحقات هنا، القرارات كلها بشرها.
class HrOffboardingCase {
  const HrOffboardingCase({
    required this.caseId,
    required this.staffId,
    required this.staffName,
    required this.employmentStatus,
    required this.status,
    required this.steps,
    this.lastWorkingOn,
    this.settlementNote = '',
    this.finalizedAt,
    this.cancelledNote = '',
  });

  final String caseId;
  final String staffId;
  final String staffName;
  final String employmentStatus;
  final String status;
  final DateTime? lastWorkingOn;
  final String settlementNote;
  final DateTime? finalizedAt;
  final String cancelledNote;
  final List<HrOffboardingStep> steps;

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isCancelled => status == 'cancelled';

  /// الخطوات التي تمنع الـ finalize وهي pending — يعرضها الشاشة بدل أن تخمّن.
  List<HrOffboardingStep> get pendingRequired => steps
      .where((step) =>
          step.code != 'access_suspension' && step.status == 'pending')
      .toList();

  factory HrOffboardingCase.fromJson(Map<String, dynamic> json) =>
      HrOffboardingCase(
        caseId: hrText(json['case_id']),
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        employmentStatus: hrText(json['employment_status']),
        status: hrText(json['status']),
        lastWorkingOn: hrDate(json['last_working_on']),
        settlementNote: hrText(json['settlement_note']),
        finalizedAt: hrDate(json['finalized_at']),
        cancelledNote: hrText(json['cancelled_note']),
        steps: hrMaps(json['steps']).map(HrOffboardingStep.fromJson).toList(),
      );
}

/// خطوة واحدة من قائمة الإنهاء: المالك والتاريخ والملاحظة ومن أغلقها.
class HrOffboardingStep {
  const HrOffboardingStep({
    required this.code,
    required this.status,
    this.ownerStaffId,
    this.ownerName,
    this.dueOn,
    this.note = '',
    this.doneByName,
    this.doneAt,
  });

  final String code;
  final String status;
  final String? ownerStaffId;
  final String? ownerName;
  final DateTime? dueOn;
  final String note;
  final String? doneByName;
  final DateTime? doneAt;

  bool get isPending => status == 'pending';
  bool get isDone => status == 'done';
  bool get isSkipped => status == 'skipped';

  factory HrOffboardingStep.fromJson(Map<String, dynamic> json) =>
      HrOffboardingStep(
        code: hrText(json['code']),
        status: hrText(json['status']),
        ownerStaffId: hrId(json['owner_staff_id']),
        ownerName: hrText(json['owner_name']),
        dueOn: hrDate(json['due_on']),
        note: hrText(json['note']),
        doneByName: hrText(json['done_by_name']),
        doneAt: hrDate(json['done_at']),
      );
}

/// لفظ الخطوة كما تقرؤه الشاشة، بترتيب القائمة المعتمد في 241.
String hrOffboardingStepLabel(String code) => switch (code) {
      'manager_review' => S.hrOffStepManager,
      'hr_review' => S.hrOffStepHr,
      'finance_review' => S.hrOffStepFinance,
      'obligations' => S.hrOffStepObligations,
      'final_settlement' => S.hrOffStepSettlement,
      'access_suspension' => S.hrOffStepAccess,
      _ => code,
    };
