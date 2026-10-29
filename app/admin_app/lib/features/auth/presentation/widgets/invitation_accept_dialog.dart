import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/presentation/manager/invitation_accept_cubit.dart';
import 'package:admin_app/features/auth/presentation/manager/invitation_accept_state.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_password_field.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// ما يرجع به الحوار حين تقبل القاعدة الدعوة: بريد الدعوة وكلمة المرور التي
/// اختار صاحبها، ليُفتح بها باب الدخول نفسه الذي يعرفه التطبيق.
class InvitationCredentials {
  const InvitationCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

/// يفتح حوار قبول رمز الدعوة من شاشة الدخول.
Future<InvitationCredentials?> showInvitationAcceptDialog(
  BuildContext context,
) {
  return showDialog<InvitationCredentials>(
    context: context,
    builder: (context) => BlocProvider(
      create: (context) => InvitationAcceptCubit(),
      child: const _InvitationAcceptDialog(),
    ),
  );
}

/// الرمز، ثم لمن هو، ثم كلمة المرور: ثلاث خطوات كما تقررها القاعدة.
///
/// الاسم والدور والفرع لا تُختلق حين لا تصل: `admin_invitation_lookup` هي التي
/// تعرف الرمز وتعد به، والشاشة تقرأ ما قالته فقط.
class _InvitationAcceptDialog extends StatefulWidget {
  const _InvitationAcceptDialog();

  @override
  State<_InvitationAcceptDialog> createState() =>
      _InvitationAcceptDialogState();
}

class _InvitationAcceptDialogState extends State<_InvitationAcceptDialog> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  /// فراغٌ محلي قبل أي سؤال للقاعدة: الرمز القصير أو الغائب لا يُرسل أصلاً.
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _check(InvitationAcceptCubit cubit) {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = S.invitationCodeRequired);
      return;
    }
    setState(() => _error = null);
    cubit.check(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InvitationAcceptCubit>();
    return BlocBuilder<InvitationAcceptCubit, InvitationAcceptState>(
      builder: (context, state) {
        final preview = state.preview;
        final refused = state.status == InvitationAcceptStatus.refused;
        return AlertDialog(
          title: Text(S.invitationAcceptTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: CustomTextFormField(
                    label: S.invitationCodeLabel,
                    hint: S.invitationCodeHint,
                    controller: _code,
                    bottomPadding: AppSizes.px8,
                    onFieldSubmitted: (_) {
                      if (preview == null) _check(cubit);
                    },
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _PreviewCard(preview: preview),
                  const SizedBox(height: AppSpacing.md),
                  LoginPasswordField(
                    controller: _password,
                    obscurePassword: _obscure,
                    onToggleVisibility: () =>
                        setState(() => _obscure = !_obscure),
                    onSubmitted: () => _accept(cubit),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AdminInlineError(message: _error!),
                ] else if (refused && state.outcome != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AdminInlineError(
                    message: invitationAcceptMessage(state.outcome!),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.cancel),
            ),
            if (preview == null)
              FilledButton(
                // النص يُقرأ لحظة الضغط: لا مستمع للحقل يعيد البناء، فلو بقيت
                // الإجابة معلَّقة بصيغة الرمز لبقي الزرّ مطفأً بلا سبب.
                onPressed: state.isBusy ? null : () => _check(cubit),
                child: Text(
                  state.status == InvitationAcceptStatus.checking
                      ? S.invitationChecking
                      : S.invitationCheck,
                ),
              )
            else
              FilledButton(
                onPressed: state.isBusy ? null : () => _accept(cubit),
                child: Text(
                  state.status == InvitationAcceptStatus.submitting
                      ? S.invitationSubmitting
                      : S.invitationAcceptSubmit,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _accept(InvitationAcceptCubit cubit) async {
    // الطول الأدنى كلمةُ المرور هنا لا في القاعدة: قاعدة Supabase ترفض الأقصر،
    // والحوار يوفّر رحلة كتابة كاملة قبل أن يكتشفها المستخدم.
    if (_password.text.length < _minimumPasswordLength) {
      setState(() => _error = S.invitationWeakPassword);
      return;
    }
    setState(() => _error = null);
    final email = await cubit.accept(
      token: _code.text,
      password: _password.text,
    );
    if (!mounted || email == null) return;
    Navigator.of(context)
        .pop(InvitationCredentials(email: email, password: _password.text));
  }

  /// أقل ما تقبله Supabase في كل المشاريع هنا؛ الأطول يمرّ بلا نقاش.
  static const int _minimumPasswordLength = 6;
}

/// لمن الدعوة وإلى أي دور، كما قالت القاعدة.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final InvitationPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.invitationAcceptedIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: adminMutedColor(theme),
            ),
          ),
          const SizedBox(height: AppSizes.px6),
          Text(
            preview.fullName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: AppFontWeights.bold,
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(preview.email, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: AppSizes.px4),
          Text(
            '${S.invitationRoleLabel}: ${preview.roleName}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${S.invitationBranchLabel}: '
            '${preview.branchName ?? S.invitationAllBranches}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// عربيّة الرفض الذي تجيب به القاعدة على رمز لا يُقبل.
String invitationAcceptMessage(InvitationAcceptOutcome outcome) =>
    switch (outcome) {
      InvitationAcceptOutcome.accepted => '',
      InvitationAcceptOutcome.unknown => S.invitationUnknown,
      InvitationAcceptOutcome.alreadyAccepted => S.invitationAlreadyAccepted,
      InvitationAcceptOutcome.cancelled => S.invitationCancelled,
      InvitationAcceptOutcome.expired => S.invitationExpired,
      InvitationAcceptOutcome.emailMismatch => S.invitationEmailMismatch,
      InvitationAcceptOutcome.alreadyStaff => S.invitationAlreadyStaff,
      InvitationAcceptOutcome.customerHistory => S.invitationCustomerHistory,
      InvitationAcceptOutcome.emailConfirmationNeeded =>
        S.invitationConfirmationNeeded,
      InvitationAcceptOutcome.weakPassword => S.invitationWeakPassword,
      InvitationAcceptOutcome.failed => S.invitationFailed,
    };
