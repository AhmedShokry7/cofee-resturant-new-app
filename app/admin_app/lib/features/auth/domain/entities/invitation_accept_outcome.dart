/// حالة قبول رمز دعوة من شاشة الدخول.
///
/// الأسباب أسماء كما ترسلها القاعدة في `admin_invitation_lookup` و
/// `admin_accept_invitation`، والنصوص العربية تُقرأ من `app_strings.dart`:
/// الشاشة لا تخترع سببًا ولا تقرر أن رمزًا ما زال حيًّا.
enum InvitationAcceptOutcome {
  /// الحساب أُنشئ وصار موظفًا نشطًا، فيُكمل الدخول بالمسار المجرب.
  accepted,

  /// الرمز غير معروف، أو فراغ.
  unknown,

  /// الرمز استُخدم من قبل.
  alreadyAccepted,
  cancelled,
  expired,

  /// الجلسة التي كتب بها المدعو لا تطابق بريد الدعوة.
  emailMismatch,

  /// البريد موظف بالفعل في الدليل.
  alreadyStaff,

  /// الحساب عليه بيانات عميل (سجل طلبات مثلًا)، والقاعدة ترفض قلبه موظفًا.
  customerHistory,

  /// القاعدة تطلب تأكيد البريد قبل أي كتابة، فلا جلسة تُنشأ هنا.
  emailConfirmationNeeded,

  /// كلمة مرور أضعف مما تطلبه Supabase.
  weakPassword,
  failed,
}

/// ما يعد به الرمز قبل أن يسجل صاحبه الدخول: لمن هو وإلى أي دور.
class InvitationPreview {
  const InvitationPreview({
    required this.email,
    required this.fullName,
    required this.roleName,
    this.branchName,
  });

  final String email;
  final String fullName;
  final String roleName;
  final String? branchName;
}

/// نتيجة قراءة الرمز: معاينة إن كان حيًّا، وسبب إن لم يكن.
class InvitationLookup {
  const InvitationLookup.found(this.preview) : outcome = null;

  const InvitationLookup.refused(this.outcome) : preview = null;

  final InvitationPreview? preview;
  final InvitationAcceptOutcome? outcome;

  bool get isFound => preview != null;
}
