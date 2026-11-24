import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/auth/di/auth_dependencies.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:admin_app/features/auth/domain/usecases/accept_invitation.dart';
import 'package:admin_app/features/auth/domain/usecases/confirm_email_and_accept_invitation.dart';
import 'package:admin_app/features/auth/domain/usecases/lookup_invitation.dart';
import 'package:admin_app/features/auth/presentation/manager/invitation_accept_state.dart';

/// يقرأ رمز دعوة ثم يسلّمه للقاعدة بعد أن يختار صاحبه كلمة مرور.
///
/// القاعدة هي الحكم في كل خطوة: `admin_invitation_lookup` تجيب لمن الرمز،
/// و`admin_accept_invitation` وحدها تقرر أن الحساب صار موظفًا. لا يضيف هذا
/// الملف حالة لا تعرفها القاعدة، ولا يعلن نجاحًا لم يأتِ منها.
class InvitationAcceptCubit extends Cubit<InvitationAcceptState> {
  InvitationAcceptCubit({AuthRepository? repository})
    : this._withUseCases(repository ?? AuthDependencies.repository);

  InvitationAcceptCubit._withUseCases(AuthRepository repository)
    : _lookup = LookupInvitationUseCase(repository),
      _accept = AcceptInvitationUseCase(repository),
      _confirmAndAccept = ConfirmEmailAndAcceptInvitationUseCase(repository),
      super(const InvitationAcceptState());

  final LookupInvitationUseCase _lookup;
  final AcceptInvitationUseCase _accept;
  final ConfirmEmailAndAcceptInvitationUseCase _confirmAndAccept;

  /// كلمة المرور التي اختارها المدعو في الخطوة الأولى، تُحفظ هنا فقط لإكمال
  /// القبول بعد تأكيد البريد؛ لا تدخل الحالة ولا تُسجَّل في أي مكان.
  String? _pendingPassword;

  /// يقرأ الرمز. الرفض هنا لا يستثنى: هو إجابة من القاعدة لها سبب.
  Future<void> check(String token) async {
    final code = token.trim();
    if (code.isEmpty) {
      emit(
        state.copyWith(
          status: InvitationAcceptStatus.refused,
          outcome: InvitationAcceptOutcome.incompleteLink,
          clearPreview: true,
          clearToken: true,
          clearError: true,
          clearOutcome: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: InvitationAcceptStatus.checking,
        token: code,
        clearPreview: true,
        clearError: true,
        clearOutcome: true,
      ),
    );
    try {
      final answer = await _lookup(code);
      final preview = answer.preview;
      if (preview == null) {
        emit(
          state.copyWith(
            status: InvitationAcceptStatus.refused,
            outcome: answer.outcome ?? InvitationAcceptOutcome.serviceFailure,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: InvitationAcceptStatus.preview,
          preview: preview,
          clearError: true,
        ),
      );
    } catch (error) {
      debugPrint(
        '[InvitationLookup] stage=lookup category=${_safeErrorCategory(error)}',
      );
      emit(
        state.copyWith(
          status: InvitationAcceptStatus.refused,
          outcome: _lookupFailureOutcome(error),
          clearError: true,
        ),
      );
    }
  }

  /// الفقرة الأخيرة: كلمة المرور لصاحب الحساب، والقرار للقاعدة.
  ///
  /// الرمز يُسلَّم كما رأت الشاشة لا كما خُزِّن عندها: الرمز من حقل النص نفسه.
  /// تجيب بالبريد الذي يجب أن تُفتح به الجلسة بعد النجاح — وهو بريد الدعوة لا
  /// ما كتبته الشاشة — وترجع null عند الرفض.
  Future<String?> accept({
    required String token,
    required String password,
  }) async {
    final preview = state.preview;
    if (preview == null) return null;
    emit(
      state.copyWith(
        status: InvitationAcceptStatus.submitting,
        clearOutcome: true,
      ),
    );
    _pendingPassword = password;
    final outcome = await _accept(
      token: state.token ?? token,
      email: preview.email,
      password: password,
    );
    if (outcome == InvitationAcceptOutcome.emailConfirmationNeeded) {
      emit(
        state.copyWith(
          status: InvitationAcceptStatus.awaitingConfirmation,
          outcome: outcome,
        ),
      );
      return null;
    }
    if (outcome != InvitationAcceptOutcome.accepted) {
      emit(
        state.copyWith(
          status: InvitationAcceptStatus.refused,
          outcome: outcome,
        ),
      );
      return null;
    }
    emit(
      state.copyWith(status: InvitationAcceptStatus.accepted, outcome: outcome),
    );
    _pendingPassword = null;
    return preview.email;
  }

  /// الخطوة الثانية حين تطلب المصادقة تأكيد البريد: كود وصل بالبريد، ثم
  /// القبول نفسه. Returns the invitation email on success, null otherwise.
  Future<String?> confirmEmail({
    required String token,
    required String confirmationCode,
  }) async {
    final preview = state.preview;
    final password = _pendingPassword;
    if (preview == null || password == null) return null;
    emit(
      state.copyWith(
        status: InvitationAcceptStatus.submitting,
        clearOutcome: true,
      ),
    );
    final outcome = await _confirmAndAccept(
      token: state.token ?? token,
      email: preview.email,
      password: password,
      confirmationCode: confirmationCode,
    );
    if (outcome != InvitationAcceptOutcome.accepted) {
      emit(
        state.copyWith(
          status: switch (outcome) {
            InvitationAcceptOutcome.emailConfirmationCodeInvalid ||
            InvitationAcceptOutcome.networkFailure ||
            InvitationAcceptOutcome.serviceFailure ||
            InvitationAcceptOutcome.failed =>
              InvitationAcceptStatus.awaitingConfirmation,
            _ => InvitationAcceptStatus.refused,
          },
          outcome: outcome,
        ),
      );
      return null;
    }
    emit(
      state.copyWith(status: InvitationAcceptStatus.accepted, outcome: outcome),
    );
    _pendingPassword = null;
    return preview.email;
  }

  static String _safeErrorCategory(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout')) {
      return 'network';
    }
    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('permission')) {
      return 'authorization';
    }
    return 'service';
  }

  static InvitationAcceptOutcome _lookupFailureOutcome(Object error) =>
      _safeErrorCategory(error) == 'network'
      ? InvitationAcceptOutcome.networkFailure
      : InvitationAcceptOutcome.serviceFailure;
}
