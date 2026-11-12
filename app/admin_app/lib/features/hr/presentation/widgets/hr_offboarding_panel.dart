import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/hr/domain/entities/hr_offboarding.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_offboarding_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_offboarding_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_note_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// لوحة إنهاء الخدمة لموظف واحد: فتح الحالة، وقائمة الخطوات بمالك كل خطوة
/// وملاحظتها، ثم تنفيذ القرار، وتعليق الدخول لاحقًا — كل قرار بقرار القاعدة
/// لا بزرّ يتخيله.
///
/// لا تُحتسب مستحقات هنا: خطوة التسوية النهائية توثيق إقرار بشري، وملاحظتها
/// تحمل ما اعتمده المالك.
class HrOffboardingPanel extends StatelessWidget {
  const HrOffboardingPanel({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.cubit,
    required this.onClose,
    required this.people,
  });

  final String staffId;
  final String staffName;
  final HrOffboardingCubit cubit;
  final VoidCallback onClose;

  /// مرشِّحو ملكية الخطوات من دليل الصفحة؛ فراغه يعني إسنادًا بلا مالك مسمّى.
  final List<HrPersonOption> people;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HrOffboardingCubit>.value(
      value: cubit,
      child: BlocBuilder<HrOffboardingCubit, HrOffboardingState>(
        builder: (context, state) {
          if (state.status == HrLoadStatus.initial ||
              (state.status == HrLoadStatus.loading && state.cases.isEmpty)) {
            return const AdminLoadingView();
          }
          if (state.status == HrLoadStatus.failure && state.cases.isEmpty) {
            return AdminFailureView(
              message:
                  state.failure == null ? null : hrRefusalMessage(state.failure!),
              onRetry: () => cubit.load(staffId),
            );
          }
          return _body(context, state);
        },
      ),
    );
  }

  Widget _body(BuildContext context, HrOffboardingState state) {
    final current = cubit.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminDialogHeader(
          title: '${S.hrOffboarding} — $staffName',
          subtitle: current == null ? S.hrOffboardingNone : S.hrOffboardingHint,
          onClose: onClose,
        ),
        HrRefusalNote(refusal: state.failure),
        const SizedBox(height: AppSpacing.sm),
        if (current == null)
          _startForm(context, state)
        else
          Expanded(child: _caseBody(context, state, current)),
      ],
    );
  }

  Widget _startForm(BuildContext context, HrOffboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomBtn(
          text: S.hrOffStart,
          variant: BtnVariant.primary,
          isLoading: state.isWriting,
          onPressed: state.isWriting
              ? null
              : () async {
                  final note = await showHrNoteDialog(
                    context,
                    title: S.hrOffStart,
                    question: staffName,
                    noteLabel: S.hrOffLastDay,
                    saveLabel: S.hrOffStart,
                    noteRequired: false,
                  );
                  if (note == null) return;
                  await cubit.start(
                    targetStaffId: staffId,
                    lastWorkingOn: DateTime.now().add(const Duration(days: 30)),
                    note: note.trim().isEmpty ? null : note.trim(),
                  );
                },
        ),
      ],
    );
  }

  Widget _caseBody(
    BuildContext context,
    HrOffboardingState state,
    HrOffboardingCase current,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HrCellText(
          current.isClosed
              ? '${S.hrOffClosed} • '
                  '${localizedDate(current.finalizedAt)}'
              : current.isCancelled
                  ? S.hrOffCancelled
                  : '${S.hrOffLastDay}: '
                      '${current.lastWorkingOn == null ? '—' : localizedDate(current.lastWorkingOn)}',
          strong: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView(
            children: [
              for (final step in current.steps)
                _step(context, state, current, step),
            ],
          ),
        ),
        if (current.isOpen) ...[
          _finalizeButton(context, state, current),
        ],
        if (current.isClosed && _accessStepPending(current)) ...[
          _suspendButton(context, state, current),
        ],
      ],
    );
  }

  bool _accessStepPending(HrOffboardingCase current) {
    for (final step in current.steps) {
      if (step.code == 'access_suspension' && step.status == 'pending') {
        return true;
      }
    }
    return false;
  }

  Widget _step(
    BuildContext context,
    HrOffboardingState state,
    HrOffboardingCase current,
    HrOffboardingStep step,
  ) {
    final label = hrOffboardingStepLabel(step.code);
    final subtitle = StringBuffer();
    if (step.ownerName != null && step.ownerName!.isNotEmpty) {
      subtitle.write('${S.hrOffOwner}: ${step.ownerName!} • ');
    }
    if (step.dueOn != null) subtitle.write(localizedDate(step.dueOn));
    if (step.note.isNotEmpty) {
      subtitle.write(' • ${step.note}');
    }
    if (step.doneByName != null) subtitle.write(' • ${step.doneByName!}');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: HrCellText(label, strong: !step.isPending),
      subtitle: subtitle.isEmpty
          ? null
          : HrCellText(subtitle.toString(), muted: true),
      trailing: _trailing(context, state, current, step),
    );
  }

  Widget? _trailing(
    BuildContext context,
    HrOffboardingState state,
    HrOffboardingCase current,
    HrOffboardingStep step,
  ) {
    if (!current.isOpen || step.isDone) {
      return HrStatusCell(step.status);
    }
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        CustomBtn(
          text: S.hrOffAssign,
          variant: BtnVariant.outlined,
          onPressed: state.isWriting
              ? null
              : () => _assignDialog(context, current, step),
        ),
        if (step.code != 'access_suspension')
          CustomBtn(
            text: S.hrOffDone,
            onPressed: state.isWriting
                ? null
                : () => _noteAndSet(context, current, step, 'done'),
          ),
        CustomBtn(
          text: S.hrOffSkip,
          variant: BtnVariant.destructive,
          onPressed: state.isWriting
              ? null
              : () => _noteAndSet(context, current, step, 'skipped'),
        ),
      ],
    );
  }

  Future<void> _assignDialog(
    BuildContext context,
    HrOffboardingCase current,
    HrOffboardingStep step,
  ) async {
    String? ownerId = step.ownerStaffId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(hrOffboardingStepLabel(step.code)),
          content: DropdownButtonFormField<String?>(
            initialValue: ownerId,
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(S.hrOffOwnerNone),
              ),
              for (final person in people)
                DropdownMenuItem<String?>(
                  value: person.id,
                  child: Text(person.name),
                ),
            ],
            onChanged: (value) => setState(() => ownerId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(S.hrActionClose),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(S.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await cubit.assignStep(
      caseId: current.caseId,
      code: step.code,
      ownerStaffId: ownerId,
    );
  }

  Future<void> _noteAndSet(
    BuildContext context,
    HrOffboardingCase current,
    HrOffboardingStep step,
    String status,
  ) async {
    final note = await showHrNoteDialog(
      context,
      title: hrOffboardingStepLabel(step.code),
      question: staffName,
      saveLabel: S.save,
      noteRequired: status == 'done',
    );
    if (note == null) return;
    await cubit.setStep(
      caseId: current.caseId,
      code: step.code,
      status: status,
      note: note,
    );
  }

  Widget _finalizeButton(
    BuildContext context,
    HrOffboardingState state,
    HrOffboardingCase current,
  ) {
    final pending = current.pendingRequired;
    final blocked = pending.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (blocked)
            HrCellText(
              '${S.hrOffPendingSteps}: '
              '${pending.map((step) => hrOffboardingStepLabel(step.code)).join(' • ')}',
              muted: true,
            ),
          CustomBtn(
            text: S.hrOffFinalize,
            variant: BtnVariant.destructive,
            isLoading: state.isWriting,
            onPressed: state.isWriting || blocked
                ? null
                : () async {
                    final note = await showHrNoteDialog(
                      context,
                      title: S.hrOffFinalize,
                      question: staffName,
                      saveLabel: S.hrOffFinalize,
                      noteRequired: false,
                    );
                    if (note == null) return;
                    await cubit.finalize(
                      caseId: current.caseId,
                      terminatedOn: DateTime.now(),
                      note: note.trim().isEmpty ? null : note.trim(),
                    );
                  },
          ),
          CustomBtn(
            text: S.hrOffCancelCase,
            variant: BtnVariant.outlined,
            onPressed: state.isWriting
                ? null
                : () async {
                    final note = await showHrNoteDialog(
                      context,
                      title: S.hrOffCancelCase,
                      question: staffName,
                      saveLabel: S.hrOffCancelCase,
                      noteRequired: false,
                    );
                    if (note == null) return;
                    await cubit.cancel(
                      caseId: current.caseId,
                      note: note.trim().isEmpty ? null : note.trim(),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _suspendButton(
    BuildContext context,
    HrOffboardingState state,
    HrOffboardingCase current,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: CustomBtn(
        text: S.hrOffSuspend,
        variant: BtnVariant.destructive,
        isLoading: state.isWriting,
        onPressed: state.isWriting
            ? null
            : () async {
                final note = await showHrNoteDialog(
                  context,
                  title: S.hrOffSuspend,
                  question: staffName,
                  saveLabel: S.hrOffSuspend,
                  noteRequired: false,
                );
                if (note == null) return;
                await cubit.suspendAccess(
                  caseId: current.caseId,
                  note: note.trim().isEmpty ? null : note.trim(),
                );
              },
      ),
    );
  }
}
