import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_state.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_code_block.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_messages.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// يفتح قائمة الدعوات التي أُرسلت.
///
/// يجيب true حين سُحبت دعوة فعلًا، فتقول الصفحة ذلك بصوتها.
Future<bool?> showStaffInvitationsDialog({
  required BuildContext context,
  required AdminStaffCubit cubit,
  required bool canManage,
}) {
  return showDialog<bool>(
    context: context,
    // حوار Route يُبنى فوق Navigator، فلا يرث مزوّد البلوك الذي يلفّ الصفحة:
    // يقدَّم له المزوّد نفسه وإلا أعاد البناء بلا حالة يقرأ منها.
    builder: (context) => BlocProvider<AdminStaffCubit>.value(
      value: cubit,
      child: StaffInvitationsDialog(cubit: cubit, canManage: canManage),
    ),
  );
}

/// الدعوات بحالتها التي تقيّمها القاعدة لحظة القراءة.
///
/// الحالة ليست من الساعة المحلية: صفٌّ ما زال `pending` في العمود لكنه تجاوز
/// أجله يرد `expired`، والرمز نفسه لا يصل إلا لمن كتب الدعوة أو لمن يدير كل
/// الفروع، فتعرض القائمة «رمزًا مخفيًّا» بلا أن تختلقه.
class StaffInvitationsDialog extends StatefulWidget {
  const StaffInvitationsDialog({
    super.key,
    required this.cubit,
    required this.canManage,
  });

  final AdminStaffCubit cubit;
  final bool canManage;

  @override
  State<StaffInvitationsDialog> createState() => _StaffInvitationsDialogState();
}

class _StaffInvitationsDialogState extends State<StaffInvitationsDialog> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.cubit.loadInvitations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(S.staffInvitations),
      content: SizedBox(
        width: 520,
        child: BlocBuilder<AdminStaffCubit, AdminStaffState>(
          buildWhen: (previous, current) =>
              previous.invitations != current.invitations ||
              previous.errorMessage != current.errorMessage,
          builder: (context, state) {
            final invitations = state.invitations;
            // فشل القراءة رسالةٌ لا فراغ: قائمة بلا دعوات غير «لم تصل الدعوات».
            final error = _error ?? state.errorMessage;
            return ListView(
              shrinkWrap: true,
              children: [
                if (error != null) ...[
                  AdminInlineError(message: error),
                  const SizedBox(height: AppSpacing.md),
                ] else if (invitations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      S.staffNoInvitations,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: adminMutedColor(theme),
                      ),
                    ),
                  )
                else
                  for (final invitation in invitations) ...[
                    _InvitationRow(
                      invitation: invitation,
                      canManage: widget.canManage,
                      onCancel: () => _cancel(invitation),
                    ),
                    // المسافات بين الصفوف لا قبل أولها.
                    if (invitation != invitations.last)
                      const SizedBox(height: AppSpacing.md),
                  ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          // الغلق وحده لا يعني أن دعوة سُحبت: الصفحة لا تقول شيئًا بلا pop(true).
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.close),
        ),
      ],
    );
  }

  Future<void> _cancel(AdminStaffInvitation invitation) async {
    setState(() => _error = null);
    final outcome = await widget.cubit.cancelInvitation(invitation.id);
    if (!mounted) return;
    if (outcome == StaffInviteOutcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = staffInviteErrorMessage(outcome));
  }
}

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({
    required this.invitation,
    required this.canManage,
    required this.onCancel,
  });

  final AdminStaffInvitation invitation;
  final bool canManage;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StaffInvitationStatusView.of(invitation.status);
    final branch = invitation.branchName(S.staffInviteAllBranches);
    final inviter = invitation.invitedByName?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.fullName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                    Text(
                      invitation.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: adminMutedColor(theme),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px8),
              AdminStatusBadge(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: AppSizes.px6),
          Text(
            '${invitation.roleName()} · $branch',
            style: theme.textTheme.bodySmall,
          ),
          if (invitation.expiresAt != null)
            Text(
              '${S.staffInvitationExpiresOn}: '
              '${localizedDate(invitation.expiresAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: adminMutedColor(theme),
              ),
            ),
          if (inviter.isNotEmpty)
            Text(
              inviter,
              style: theme.textTheme.bodySmall?.copyWith(
                color: adminMutedColor(theme),
              ),
            ),
          if (invitation.canShareCode && invitation.token != null) ...[
            const SizedBox(height: AppSizes.px8),
            StaffCodeBlock(code: invitation.token!),
          ],
          if (canManage && invitation.isPending) ...[
            const SizedBox(height: AppSizes.px4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onCancel,
                child: Text(S.staffInvitationCancel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
