import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';

/// عقد الإجازات: طلب الموظف ومراجعة المدير ورصيد السنة.
abstract interface class HrLeaveRepository {
  /// طلب باسم الموظف نفسه؛ القاعدة لا تقرأ `p_staff_id` من المتصل أصلًا.
  Future<HrReceipt> requestLeave({
    required String leaveTypeId,
    required DateTime startsOn,
    required DateTime endsOn,
    String? reason,
    String? supportingDocument,
  });

  Future<HrReceipt> cancelRequest({required String requestId, String? note});

  Future<List<HrLeaveRequest>> loadRequests({String? status, String? staffId});

  /// الاعتماد وحده يستهلك الرصيد، والرفض لا يلمسه. لا يقر أحد طلب نفسه — ولا
  /// يملك المالك هنا استثناء، لأن الطلبات كلها في `leave_requests`.
  Future<HrReceipt> reviewRequest({
    required String requestId,
    required bool approve,
    String? note,
  });

  /// الرصيد يُكتب لسنة؛ `used_days` لا يمسّه أحد من هنا.
  Future<HrLeaveBalance> setBalance({
    required String staffId,
    required String leaveTypeId,
    required int year,
    required double entitledDays,
  });
}
