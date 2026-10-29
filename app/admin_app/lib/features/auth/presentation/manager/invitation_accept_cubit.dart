import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/auth/di/auth_dependencies.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:admin_app/features/auth/domain/usecases/accept_invitation.dart';
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
      super(const InvitationAcceptState());

  final LookupInvitationUseCase _lookup;
  final AcceptInvitationUseCase _accept;

  /// يقرأ الرمز. الرفض هنا لا يستثنى: هو إجابة من القاعدة لها سبب.
  Future<void> check(String token) async {
    emit(
      state.copyWith(
        status: InvitationAcceptStatus.checking,
        clearPreview: true,
        clearError: true,
      ),
    );
    try {
      final answer = await _lookup(token);
      final preview = answer.preview;
      if (preview == null) {
        emit(
          state.copyWith(
            status: InvitationAcceptStatus.refused,
            outcome: answer.outcome ?? InvitationAcceptOutcome.failed,
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
      emit(
        state.copyWith(
          status: InvitationAcceptStatus.refused,
          outcome: InvitationAcceptOutcome.failed,
          errorMessage: '$error',
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
    emit(state.copyWith(status: InvitationAcceptStatus.submitting));
    final outcome = await _accept(
      token: token,
      email: preview.email,
      password: password,
    );
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
    return preview.email;
  }
}
