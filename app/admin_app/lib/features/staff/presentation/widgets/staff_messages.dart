import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';

/// الرسالة التي تعرضها شاشة بيانات الموظف عند رفض القاعدة تعديلًا.
String staffEditErrorMessage(StaffEditOutcome outcome) => switch (outcome) {
  StaffEditOutcome.success => '',
  StaffEditOutcome.permissionDenied => S.staffEditPermissionDenied,
  StaffEditOutcome.selfStatus => S.staffEditSelfStatus,
  StaffEditOutcome.invalidName => S.staffEditInvalidName,
  StaffEditOutcome.invalidEmail => S.staffEditInvalidEmail,
  StaffEditOutcome.duplicateEmail => S.staffEditDuplicateEmail,
  StaffEditOutcome.invalidStatus => S.staffEditInvalidStatus,
  StaffEditOutcome.invalidPath => S.staffEditInvalidPath,
  StaffEditOutcome.failed => S.staffEditFailed,
};

/// الرسالة التي يقولها نموذج الدعوة أو قائمة الدعوات عند رفض القاعدة.
///
/// أسباب الاسم والبريد هي أسباب التعديل نفسها — نصٌّ واحد لمعنىً واحد — وما
/// يبقى خاصًّا بالدعوة هو النطاق والدور والحالة.
String staffInviteErrorMessage(StaffInviteOutcome outcome) => switch (outcome) {
  StaffInviteOutcome.success => '',
  StaffInviteOutcome.permissionDenied => S.staffInvitePermissionDenied,
  StaffInviteOutcome.invalidEmail => S.staffEditInvalidEmail,
  StaffInviteOutcome.invalidName => S.staffEditInvalidName,
  StaffInviteOutcome.unknownRole => S.staffInviteUnknownRole,
  StaffInviteOutcome.ownerOnly => S.staffInviteOwnerOnly,
  StaffInviteOutcome.notYourBranch => S.staffInviteNotYourBranch,
  StaffInviteOutcome.unknownBranch => S.staffInviteUnknownBranch,
  StaffInviteOutcome.alreadyInvited => S.staffInviteAlreadyInvited,
  StaffInviteOutcome.alreadyStaff => S.staffInviteAlreadyStaff,
  StaffInviteOutcome.notFound => S.staffInviteNotFound,
  StaffInviteOutcome.notPending => S.staffInviteNotPending,
  StaffInviteOutcome.failed => S.staffInviteFailed,
};
