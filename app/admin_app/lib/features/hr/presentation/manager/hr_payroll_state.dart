import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll_preview.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة الرواتب: دورات الشهر، ودورة مفتوحة بقسيماتها، وقسيمة واحدة بالتفصيل.
class HrPayrollState {
  const HrPayrollState({
    this.status = HrLoadStatus.initial,
    this.runs = const <HrPayrollRun>[],
    this.run,
    this.statement,
    this.failure,
    this.writing = HrWriteStatus.idle,
    this.receipt,
    this.preview,
    this.previewStatus = HrLoadStatus.initial,
    this.previewFailure,
  });

  final HrLoadStatus status;
  final List<HrPayrollRun> runs;

  /// الدورة المفتوحة: `null` حتى تُطلب، وقسيماتها تأتي معها لا مع القائمة.
  final HrPayrollRun? run;

  /// قسيمة واحدة بأسطرها، حين يفتحها المدير من دورة.
  final HrPayrollStatement? statement;

  final HrRefusal? failure;
  final HrWriteStatus writing;

  /// إيصال آخر كتابة: الحالة التي انتهى إليها السطر، وأرقامها إن أعطتها الدالة.
  final HrReceipt? receipt;

  /// معاينة الفترة من `admin_hr_preview_payroll`: قراءة نقية لا تصدر عن الشاشة
  /// أي رقم، و`null` ما لم تُطلب.
  final HrPayrollPreview? preview;
  final HrLoadStatus previewStatus;

  /// رفض المعاينة وحدها، حتى لا يمحو رفضها قراءة القوائم ولا العكس.
  final HrRefusal? previewFailure;

  bool get isLoading => status == HrLoadStatus.loading;
  bool get isWriting => writing == HrWriteStatus.sending;

  HrPayrollState copyWith({
    HrLoadStatus? status,
    List<HrPayrollRun>? runs,
    HrPayrollRun? run,
    bool clearRun = false,
    HrPayrollStatement? statement,
    bool clearStatement = false,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
    HrReceipt? receipt,
    HrPayrollPreview? preview,
    bool clearPreview = false,
    HrLoadStatus? previewStatus,
    HrRefusal? previewFailure,
    bool clearPreviewFailure = false,
  }) => HrPayrollState(
    status: status ?? this.status,
    runs: runs ?? this.runs,
    run: clearRun ? null : (run ?? this.run),
    statement: clearStatement ? null : (statement ?? this.statement),
    failure: clearFailure ? null : (failure ?? this.failure),
    writing: writing ?? this.writing,
    receipt: receipt ?? this.receipt,
    preview: clearPreview ? null : (preview ?? this.preview),
    previewStatus: previewStatus ?? this.previewStatus,
    previewFailure: clearPreviewFailure ? null : (previewFailure ?? this.previewFailure),
  );
}
