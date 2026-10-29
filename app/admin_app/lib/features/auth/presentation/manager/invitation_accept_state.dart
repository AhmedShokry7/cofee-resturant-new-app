import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';

enum InvitationAcceptStatus {
  initial,
  checking,
  preview,
  refusing,
  submitting,
  accepted,
  refused,
}

/// حالة حوار قبول الدعوة: الرمز، ثم لمن هو، ثم نتيجة التسليم.
///
/// المعاينة ليست قرارًا من الشاشة: ما يرد في [preview] هو ما وعدت به القاعدة،
/// و`accepted` وحدها تعني أن الحساب صار موظفًا.
class InvitationAcceptState {
  const InvitationAcceptState({
    this.status = InvitationAcceptStatus.initial,
    this.preview,
    this.outcome,
    this.errorMessage,
  });

  final InvitationAcceptStatus status;
  final InvitationPreview? preview;
  final InvitationAcceptOutcome? outcome;
  final String? errorMessage;

  bool get isBusy =>
      status == InvitationAcceptStatus.checking ||
      status == InvitationAcceptStatus.submitting;

  InvitationAcceptState copyWith({
    InvitationAcceptStatus? status,
    InvitationPreview? preview,
    InvitationAcceptOutcome? outcome,
    String? errorMessage,
    bool clearPreview = false,
    bool clearError = false,
  }) {
    return InvitationAcceptState(
      status: status ?? this.status,
      preview: clearPreview ? null : (preview ?? this.preview),
      outcome: outcome ?? this.outcome,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
