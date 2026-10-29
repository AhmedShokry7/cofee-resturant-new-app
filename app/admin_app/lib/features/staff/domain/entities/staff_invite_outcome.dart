/// نتيجة دعوة موظف جديد، كما ترد من `public.admin_invite_staff`.
///
/// الأسباب تبقى أرقامًا هنا لا نصوصًا في الشاشة: القاعدة هي التي تقرر أي بريد
/// أي بريد مسموح وأي دور يجوز منحه وأي فرع هو في نطاق الموظف، والدليل يعيد
/// عربيته المطابقة من `staff_messages.dart`.
enum StaffInviteOutcome {
  success,

  /// الحساب خارج صلاحية `admin.staff.write` أو لا سجل موظف فاعل له: `42501`.
  permissionDenied,
  invalidEmail,
  invalidName,

  /// دور غير موجود في `identity.roles`.
  unknownRole,

  /// محاولة منح دور `owner` بلا أن يكون الداعي مالكًا نفسه.
  ownerOnly,

  /// الفرع المذكور ليس في نطاق الموظف، أو دعوة بلا فرع من مدير فرع.
  notYourBranch,
  unknownBranch,

  /// هناك دعوة حيّة لنفس البريد؛ يُشار إلى صفّها في [StaffInviteResult].
  alreadyInvited,

  /// البريد موظف فعلًا في الدليل، فلا معنى لدعوته من جديد.
  alreadyStaff,

  /// الدعوة لم تُوجد (إلغاء رمز محذوف).
  notFound,

  /// الدعوة استُخدمت أو سُلِبت أو انتهت، فلا تُلغى مرة ثانية.
  notPending,
  failed,
}

/// ما تجيب به القاعدة عند نجاح الدعوة: المعرّف ورمز القبول.
///
/// الرمز يصل مرة واحدة، إلى من كتب الدعوة وحده: قائمة الدعوات تخبئه عن كل
/// آخرين، فلا يعوّل عليها النموذج في عرضه.
class StaffInviteResult {
  const StaffInviteResult({
    required this.outcome,
    this.invitationId,
    this.code,
    this.email,
  });

  const StaffInviteResult.refused(this.outcome)
    : invitationId = null,
      code = null,
      email = null;

  final StaffInviteOutcome outcome;
  final String? invitationId;

  /// رمز القبول الذي يعطيه المدير للمدعو.
  final String? code;

  /// البريد كما خُزّن: أحرف صغيرة، وهو ما يجب أن يتطابق معه حساب المدعو.
  final String? email;

  bool get isSuccess => outcome == StaffInviteOutcome.success;
}
