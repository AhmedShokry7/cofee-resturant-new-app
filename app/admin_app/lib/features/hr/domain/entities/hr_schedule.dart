import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// وردية عمل مجدولة من `hr.work_schedules` عبر `admin_hr_schedules()`.
///
/// لا علاقة لها بصندوق الكاشير: هذه متى يُفترض أن يعمل الموظف، وتلك جلسة عدّ
/// نقود في `payments.pos_shifts`. تعيشان مساري حالة مختلفين وتُعرضان منفصلتين.
class HrWorkSchedule {
  const HrWorkSchedule({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.branchId,
    required this.branchName,
    required this.dayLocal,
    required this.startLocal,
    required this.endLocal,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.breakMinutes,
    required this.hours,
    required this.status,
    required this.note,
    required this.createdByName,
    required this.updatedByName,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String branchId;
  final String branchName;

  /// التاريخ باليوم المحلي، والوقت بنصه المحلي من `hr.fmt_ts`.
  final String dayLocal;
  final String startLocal;
  final String endLocal;

  /// الطابعان الكاملان، لبناء نموذج التعديل بلا تحويل ناقص.
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final int breakMinutes;

  /// الساعات بعد طرح الراحة، بمرتبتين حسبتهنّ القاعدة.
  final double hours;

  /// `draft|published|cancelled` — لا تُقارَن الحضور إلا بـ published.
  final String status;
  final String note;
  final String createdByName;
  final String updatedByName;

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isCancelled => status == 'cancelled';

  /// اليوم كما تعرضه الشاشة.
  ///
  /// قائمة الجداول ترسل `date_local`، أما ردّ `admin_hr_save_schedule()` فلا
  /// يرسله: بلا هذا الاحتياطية يعمود اليوم بعد الحفظ مباشرة، وهو أسوأ موضع
  /// للخطأ لأن المدير يراجع ما كتبه للتوه.
  String get day {
    if (dayLocal.isNotEmpty) return dayLocal;
    // `hr.fmt_ts` نصّه `YYYY-MM-DD HH:MI`، فأول عشرة منه اليوم بالحسابة التجاري.
    if (startLocal.length >= 10) return startLocal.substring(0, 10);
    return '';
  }

  factory HrWorkSchedule.fromJson(Map<String, dynamic> json) => HrWorkSchedule(
    id: hrText(json['id']),
    staffId: hrText(json['staff_id']),
    staffName: hrText(json['staff_name']),
    branchId: hrText(json['branch_id']),
    branchName: hrText(json['branch_name_ar']).isEmpty
        ? hrText(json['branch_name_en'])
        : hrText(json['branch_name_ar']),
    dayLocal: hrText(json['date_local']),
    startLocal: hrText(json['start_local']),
    endLocal: hrText(json['end_local']),
    scheduledStart: hrDate(json['scheduled_start']),
    scheduledEnd: hrDate(json['scheduled_end']),
    breakMinutes: hrInt(json['break_minutes']),
    hours: hrNum(json['hours']),
    status: hrText(json['status']),
    note: hrText(json['note']),
    createdByName: hrText(json['created_by_name']),
    updatedByName: hrText(json['updated_by_name']),
  );
}
