import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/admin_page_frame.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../domain/offboarding_models.dart';
import '../domain/offboarding_repository.dart';
import 'hr_offboarding_cubit.dart';
import 'hr_offboarding_strings.dart';

/// Existing server-side employee and branch checks remain authoritative.
/// Callers pass permissions explicitly so shell navigation can be wired later.
class HrOffboardingPage extends StatelessWidget {
  const HrOffboardingPage({
    super.key,
    required this.canRead,
    required this.canWrite,
    this.repository,
  });

  final bool canRead;
  final bool canWrite;
  final HrOffboardingRepository? repository;

  @override
  Widget build(BuildContext context) {
    if (!canRead) return Center(child: Text(HrOffboardingStrings.accessDenied));
    return BlocProvider(
      create: (_) => HrOffboardingCubit(repository: repository)..load(),
      child: _OffboardingBody(canWrite: canWrite),
    );
  }
}

class _OffboardingBody extends StatelessWidget {
  const _OffboardingBody({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<HrOffboardingCubit, HrOffboardingState>(
        builder: (context, state) {
          if (state.loading && state.cases.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.cases.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error!, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: context.read<HrOffboardingCubit>().load,
                    child: Text(HrOffboardingStrings.retry),
                  ),
                ],
              ),
            );
          }
          final cubit = context.read<HrOffboardingCubit>();
          return AdminPageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: HrOffboardingStrings.title,
                  subtitle: HrOffboardingStrings.subtitle,
                  actions: [
                    if (canWrite)
                      FilledButton.icon(
                        onPressed: state.saving
                            ? null
                            : () => _start(context, state.people, cubit),
                        icon: const AppIcon(AppIcons.add01, size: 18),
                        label: Text(HrOffboardingStrings.start),
                      ),
                  ],
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: state.cases.isEmpty
                      ? Center(child: Text(HrOffboardingStrings.empty))
                      : RefreshIndicator(
                          onRefresh: cubit.load,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: state.cases.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) => _CaseCard(
                              item: state.cases[index],
                              people: state.people,
                              canWrite: canWrite,
                              saving: state.saving,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      );

  Future<void> _start(
    BuildContext context,
    List<HrOffboardingPerson> people,
    HrOffboardingCubit cubit,
  ) async {
    final activeIds = cubit.state.cases
        .where((item) => item.status != 'cancelled')
        .map((item) => item.staffId)
        .toSet();
    final choices = people
        .where((person) => !activeIds.contains(person.staffId))
        .toList();
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(HrOffboardingStrings.noPeople)));
      return;
    }
    final data = await showDialog<_StartData>(
      context: context,
      builder: (_) => _StartDialog(people: choices),
    );
    if (data == null || !context.mounted) return;
    final success = await cubit.startCase(
      staffId: data.staffId,
      lastWorkingOn: data.lastDay,
      note: data.note,
    );
    if (success && context.mounted) {
      _snack(context, HrOffboardingStrings.created);
    }
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.item,
    required this.people,
    required this.canWrite,
    required this.saving,
  });
  final HrOffboardingCase item;
  final List<HrOffboardingPerson> people;
  final bool canWrite;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HrOffboardingCubit>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: AppIcon(
          item.isOpen ? AppIcons.clock01 : AppIcons.user,
          color: item.isOpen ? AppColor.adminAccent : null,
          size: 18,
        ),
        title: Text(
          item.staffName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _StatusPill(label: HrOffboardingStrings.status(item.status)),
            if (item.lastWorkingOn != null)
              Text(
                '${HrOffboardingStrings.lastDay}: ${_date(item.lastWorkingOn)}',
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              HrOffboardingStrings.checklist,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final step in item.steps)
            _StepTile(
              item: item,
              step: step,
              people: people,
              canWrite:
                  canWrite && item.isOpen && step.code != 'access_suspension',
              saving: saving,
            ),
          if (item.settlementNote.isNotEmpty)
            ListTile(
              dense: true,
              title: Text(HrOffboardingStrings.finalSettlement),
              subtitle: Text(item.settlementNote),
            ),
          if (item.finalizedByName != null)
            ListTile(
              dense: true,
              title: Text(HrOffboardingStrings.finalizedBy),
              subtitle: Text(item.finalizedByName!),
            ),
          if (item.isOpen && canWrite) ...[
            const Divider(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: saving ? null : () => _cancel(context, cubit),
                  icon: const AppIcon(AppIcons.cancel01, size: 17),
                  label: Text(HrOffboardingStrings.cancelCase),
                ),
                FilledButton.icon(
                  onPressed: saving || !_readyToFinalize
                      ? null
                      : () => _finalize(context, cubit),
                  icon: const AppIcon(AppIcons.checkmarkCircle01, size: 17),
                  label: Text(HrOffboardingStrings.finalize),
                ),
              ],
            ),
          ],
          if (item.isClosed && canWrite && !_accessSuspended)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : () => _suspend(context, cubit),
                  icon: const AppIcon(AppIcons.password, size: 17),
                  label: Text(HrOffboardingStrings.suspendAccess),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get _readyToFinalize =>
      item.step('final_settlement')?.status == 'done' &&
      item.steps
          .where(
            (step) =>
                step.code != 'access_suspension' &&
                step.code != 'final_settlement',
          )
          .every((step) => step.status != 'pending');
  bool get _accessSuspended => item.step('access_suspension')?.status == 'done';

  Future<void> _cancel(BuildContext context, HrOffboardingCubit cubit) async {
    final note = await _noteDialog(context, HrOffboardingStrings.confirmCancel);
    if (note == null || !context.mounted) return;
    final success = await cubit.cancelCase(caseId: item.caseId, note: note);
    if (success && context.mounted) _snack(context, HrOffboardingStrings.saved);
  }

  Future<void> _finalize(BuildContext context, HrOffboardingCubit cubit) async {
    final data = await showDialog<_FinalizeData>(
      context: context,
      builder: (_) => _FinalizeDialog(item: item),
    );
    if (data == null || !context.mounted) return;
    final success = await cubit.finalizeCase(
      caseId: item.caseId,
      terminatedOn: data.date,
      settlementNote: data.settlementNote,
    );
    if (success && context.mounted) _snack(context, HrOffboardingStrings.saved);
  }

  Future<void> _suspend(BuildContext context, HrOffboardingCubit cubit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(HrOffboardingStrings.suspendAccess),
        content: Text(HrOffboardingStrings.suspendWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(HrOffboardingStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(HrOffboardingStrings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final note = await _noteDialog(context, HrOffboardingStrings.suspendAccess);
    if (note == null || !context.mounted) return;
    final success = await cubit.suspendAccess(caseId: item.caseId, note: note);
    if (success && context.mounted) _snack(context, HrOffboardingStrings.saved);
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.item,
    required this.step,
    required this.people,
    required this.canWrite,
    required this.saving,
  });
  final HrOffboardingCase item;
  final HrOffboardingStep step;
  final List<HrOffboardingPerson> people;
  final bool canWrite;
  final bool saving;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(HrOffboardingStrings.step(step.code)),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${HrOffboardingStrings.status(step.status)} · ${step.ownerName ?? HrOffboardingStrings.noOwner}',
        ),
        if (step.dueOn != null)
          Text('${HrOffboardingStrings.dueDate}: ${_date(step.dueOn)}'),
        if (step.note.isNotEmpty) Text(step.note),
      ],
    ),
    trailing: canWrite
        ? IconButton(
            tooltip: HrOffboardingStrings.assign,
            onPressed: saving
                ? null
                : () => _assign(context, context.read<HrOffboardingCubit>()),
            icon: const AppIcon(AppIcons.userSettings01, size: 18),
          )
        : null,
    onTap: canWrite && step.code != 'access_suspension'
        ? () => _setStatus(context, context.read<HrOffboardingCubit>())
        : null,
  );

  Future<void> _assign(BuildContext context, HrOffboardingCubit cubit) async {
    final data = await showDialog<_AssignmentData>(
      context: context,
      builder: (_) => _AssignmentDialog(step: step, people: people),
    );
    if (data == null || !context.mounted) return;
    final success = await cubit.assignStep(
      caseId: item.caseId,
      code: step.code,
      ownerStaffId: data.ownerId,
      dueOn: data.dueOn,
    );
    if (success && context.mounted) _snack(context, HrOffboardingStrings.saved);
  }

  Future<void> _setStatus(
    BuildContext context,
    HrOffboardingCubit cubit,
  ) async {
    final data = await showDialog<_StepUpdate>(
      context: context,
      builder: (_) => _StepUpdateDialog(step: step),
    );
    if (data == null || !context.mounted) return;
    final success = await cubit.setStep(
      caseId: item.caseId,
      code: step.code,
      status: data.status,
      note: data.note,
    );
    if (success && context.mounted) _snack(context, HrOffboardingStrings.saved);
  }
}

class _StartData {
  const _StartData(this.staffId, this.lastDay, this.note);
  final String staffId;
  final DateTime? lastDay;
  final String note;
}

class _StartDialog extends StatefulWidget {
  const _StartDialog({required this.people});
  final List<HrOffboardingPerson> people;
  @override
  State<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends State<_StartDialog> {
  String? _staffId;
  DateTime? _lastDay;
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrOffboardingStrings.start),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _staffId,
              decoration: InputDecoration(
                labelText: HrOffboardingStrings.employee,
              ),
              items: [
                for (final person in widget.people)
                  DropdownMenuItem(
                    value: person.staffId,
                    child: Text(
                      person.name.isEmpty ? person.email : person.name,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _staffId = value),
            ),
            _DateField(
              label: HrOffboardingStrings.lastDay,
              value: _lastDay,
              onChanged: (value) => setState(() => _lastDay = value),
            ),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(labelText: HrOffboardingStrings.note),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrOffboardingStrings.cancel),
      ),
      FilledButton(
        onPressed: _staffId == null
            ? null
            : () => Navigator.pop(
                context,
                _StartData(_staffId!, _lastDay, _note.text.trim()),
              ),
        child: Text(HrOffboardingStrings.start),
      ),
    ],
  );
}

class _AssignmentData {
  const _AssignmentData(this.ownerId, this.dueOn);
  final String? ownerId;
  final DateTime? dueOn;
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.step, required this.people});
  final HrOffboardingStep step;
  final List<HrOffboardingPerson> people;
  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late String? _owner = widget.step.ownerStaffId;
  late DateTime? _due = widget.step.dueOn;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrOffboardingStrings.assign),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _owner,
            decoration: InputDecoration(labelText: HrOffboardingStrings.owner),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(HrOffboardingStrings.noOwner),
              ),
              for (final person in widget.people)
                DropdownMenuItem<String?>(
                  value: person.staffId,
                  child: Text(person.name.isEmpty ? person.email : person.name),
                ),
            ],
            onChanged: (value) => setState(() => _owner = value),
          ),
          _DateField(
            label: HrOffboardingStrings.dueDate,
            value: _due,
            onChanged: (value) => setState(() => _due = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrOffboardingStrings.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _AssignmentData(_owner, _due)),
        child: Text(HrOffboardingStrings.save),
      ),
    ],
  );
}

class _StepUpdate {
  const _StepUpdate(this.status, this.note);
  final String status;
  final String note;
}

class _StepUpdateDialog extends StatefulWidget {
  const _StepUpdateDialog({required this.step});
  final HrOffboardingStep step;
  @override
  State<_StepUpdateDialog> createState() => _StepUpdateDialogState();
}

class _StepUpdateDialogState extends State<_StepUpdateDialog> {
  late String _status = widget.step.status;
  late final TextEditingController _note = TextEditingController(
    text: widget.step.note,
  );
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrOffboardingStrings.step(widget.step.code)),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            items: [
              for (final status in ['pending', 'done', 'skipped'])
                DropdownMenuItem(
                  value: status,
                  child: Text(HrOffboardingStrings.status(status)),
                ),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          TextField(
            controller: _note,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: HrOffboardingStrings.note,
              helperText: _status == 'done'
                  ? HrOffboardingStrings.requiredNote
                  : null,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrOffboardingStrings.cancel),
      ),
      FilledButton(
        onPressed: _status == 'done' && _note.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _StepUpdate(_status, _note.text.trim()),
              ),
        child: Text(HrOffboardingStrings.save),
      ),
    ],
  );
}

class _FinalizeData {
  const _FinalizeData(this.date, this.settlementNote);
  final DateTime date;
  final String settlementNote;
}

class _FinalizeDialog extends StatefulWidget {
  const _FinalizeDialog({required this.item});
  final HrOffboardingCase item;
  @override
  State<_FinalizeDialog> createState() => _FinalizeDialogState();
}

class _FinalizeDialogState extends State<_FinalizeDialog> {
  DateTime? _date;
  late final TextEditingController _note = TextEditingController(
    text: widget.item.settlementNote,
  );
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrOffboardingStrings.finalize),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DateField(
            label: HrOffboardingStrings.terminatedOn,
            value: _date,
            onChanged: (value) => setState(() => _date = value),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(HrOffboardingStrings.settlementInstruction),
            ),
          ),
          TextField(
            controller: _note,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: HrOffboardingStrings.finalSettlement,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrOffboardingStrings.cancel),
      ),
      FilledButton(
        onPressed: _date == null || _note.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _FinalizeData(_date!, _note.text.trim()),
              ),
        child: Text(HrOffboardingStrings.finalize),
      ),
    ],
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(_date(value) ?? '—'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          IconButton(
            tooltip: HrOffboardingStrings.cancel,
            onPressed: () => onChanged(null),
            icon: const AppIcon(AppIcons.cancel01, size: 16),
          ),
        IconButton(
          tooltip: label,
          icon: const AppIcon(AppIcons.calendar01, size: 18),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    ),
  );
}

Future<String?> _noteDialog(BuildContext context, String title) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(labelText: HrOffboardingStrings.note),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(HrOffboardingStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(HrOffboardingStrings.confirm),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

String? _date(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
