import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة الحضور: صفحات الجلسات، وصحّاح الطلبات المعلّقة، في شاشة واحدة.
class HrAttendanceState {
  const HrAttendanceState({
    this.status = HrLoadStatus.initial,
    this.rows = const <HrAttendanceRow>[],
    this.corrections = const <HrAttendanceCorrection>[],
    this.failure,
    this.writing = HrWriteStatus.idle,
    this.receipt,
  });

  final HrLoadStatus status;

  /// جلسات المدى المختار كما رآها النطاق: لا تُخْترع أصفار لغياب القراءة.
  final List<HrAttendanceRow> rows;
  final List<HrAttendanceCorrection> corrections;

  final HrRefusal? failure;
  final HrWriteStatus writing;
  final HrReceipt? receipt;

  bool get isLoading => status == HrLoadStatus.loading;
  bool get isWriting => writing == HrWriteStatus.sending;
  int get pendingCorrections => corrections.where((c) => c.isPending).length;

  HrAttendanceState copyWith({
    HrLoadStatus? status,
    List<HrAttendanceRow>? rows,
    List<HrAttendanceCorrection>? corrections,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
    HrReceipt? receipt,
  }) => HrAttendanceState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    corrections: corrections ?? this.corrections,
    failure: clearFailure ? null : (failure ?? this.failure),
    writing: writing ?? this.writing,
    receipt: receipt ?? this.receipt,
  );
}
