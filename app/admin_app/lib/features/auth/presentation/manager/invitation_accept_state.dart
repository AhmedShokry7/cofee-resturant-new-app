import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';

enum InvitationAcceptStatus {
  initial,
  checking,
  preview,
  refusing,
  submitting,
  awaitingConfirmation,
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
    this.token,
  });

  final InvitationAcceptStatus status;
  final InvitationPreview? preview;
  final InvitationAcceptOutcome? outcome;
  final String? errorMessage;
  final String? token;

  bool get isBusy =>
      status == InvitationAcceptStatus.checking ||
      status == InvitationAcceptStatus.submitting ||
      status == InvitationAcceptStatus.awaitingConfirmation;

  InvitationAcceptState copyWith({
    InvitationAcceptStatus? status,
    InvitationPreview? preview,
    InvitationAcceptOutcome? outcome,
    String? errorMessage,
    bool clearPreview = false,
    bool clearError = false,
    bool clearOutcome = false,
    String? token,
    bool clearToken = false,
  }) {
    return InvitationAcceptState(
      status: status ?? this.status,
      preview: clearPreview ? null : (preview ?? this.preview),
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      token: clearToken ? null : (token ?? this.token),
    );
  }
}
