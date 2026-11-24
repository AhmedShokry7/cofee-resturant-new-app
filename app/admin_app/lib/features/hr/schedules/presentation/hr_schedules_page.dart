import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/hr/schedules/domain/hr_schedule.dart';
import 'package:admin_app/features/hr/schedules/presentation/hr_schedules_cubit.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';
import 'package:admin_app/core/theme/app_icons.dart';

class HrSchedulesPage extends StatefulWidget {
  const HrSchedulesPage({
    super.key,
    required this.canManage,
    required this.canReadEmployees,
    this.cubit,
  });

  final bool canManage;
  final bool canReadEmployees;
  final HrSchedulesCubit? cubit;

  @override
  State<HrSchedulesPage> createState() => _HrSchedulesPageState();
}

class _HrSchedulesPageState extends State<HrSchedulesPage> {
  late final HrSchedulesCubit _cubit;
  late final bool _ownsCubit;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrSchedulesCubit();
    final today = DateUtils.dateOnly(DateTime.now());
    _from = today;
    _to = today.add(const Duration(days: 13));
    _load();
  }

  Future<void> _load({String? branchId}) => _cubit.load(
    from: _from,
    to: _to,
    canReadEmployees: widget.canReadEmployees,
    branchId: branchId,
  );

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrSchedulesCubit, HrSchedulesState>(
      builder: (context, state) {
        if (state.status == HrSchedulesStatus.initial ||
            (state.status == HrSchedulesStatus.loading &&
                state.branches.isEmpty &&
                state.schedules.isEmpty)) {
          return const AdminLoadingView();
        }
        if (state.status == HrSchedulesStatus.failure &&
            state.schedules.isEmpty) {
          return AdminFailureView(message: state.error, onRetry: _load);
        }
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.hrSchedules,
                subtitle: S.hrSchedulesSubtitle,
                actions: [
                  if (widget.canManage && widget.canReadEmployees)
                    AdminCreateButton(
                      label: S.hrCreateSchedule,
                      onPressed:
                          state.employees.isEmpty || state.branches.isEmpty
                          ? null
                          : () => _openEditor(context, state),
                    ),
                ],
              ),
              if (widget.canManage && !widget.canReadEmployees)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _AccessNote(
                    message: S.hrScheduleEmployeePickerRequired,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _filters(context, state),
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
                child: state.schedules.isEmpty
                    ? Center(child: Text(S.hrScheduleNoRows))
                    : _scheduleList(state.schedules),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _filters(BuildContext context, HrSchedulesState state) =>
      AdminDirectoryPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dateFilter(context, S.hrFromDate, _from, (date) {
              setState(() => _from = date);
              _load(branchId: state.branchId);
            }),
            _dateFilter(context, S.hrToDate, _to, (date) {
              setState(() => _to = date);
              _load(branchId: state.branchId);
            }),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                initialValue: state.branchId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: S.branchLabel,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(S.hrAllBranches),
                  ),
                  ...state.branches.map(
                    (branch) => DropdownMenuItem<String?>(
                      value: branch.id,
                      child: Text(
                        AppLocale.instance.isArabic
                            ? (branch.nameAr.isEmpty
                                  ? branch.nameEn
                                  : branch.nameAr)
                            : (branch.nameEn.isEmpty
                                  ? branch.nameAr
                                  : branch.nameEn),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => _load(branchId: value),
              ),
            ),
          ],
        ),
      );

  Widget _dateFilter(
    BuildContext context,
    String label,
    DateTime date,
    ValueChanged<DateTime> changed,
  ) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) changed(DateUtils.dateOnly(picked));
    },
    icon: const AppIcon(AppIcons.calendar01, size: 17),
    label: Text('$label: ${_day(date)}'),
  );

  Widget _scheduleList(List<HrSchedule> schedules) => ListView.separated(
    itemCount: schedules.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, index) {
      final schedule = schedules[index];
      final branch = _cubit.state.branches
          .where((value) => value.id == schedule.branchId)
          .firstOrNull;
      final branchName = branch == null
          ? schedule.branchName
          : AppLocale.instance.isArabic
          ? (branch.nameAr.isEmpty ? branch.nameEn : branch.nameAr)
          : (branch.nameEn.isEmpty ? branch.nameAr : branch.nameEn);
      return AdminDirectoryPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedule.staffName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_statusLabel(schedule.status))),
              ],
            ),
            Text('$branchName · ${_day(schedule.start.toLocal())}'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${S.hrShiftStart}: ${_time(schedule.start)}  ·  ${S.hrShiftEnd}: ${_time(schedule.end)}',
            ),
            Text('${S.hrBreakMinutes}: ${schedule.breakMinutes}'),
            if (schedule.note.trim().isNotEmpty) Text(schedule.note),
            if (widget.canManage) ...[
              const Divider(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  if (widget.canReadEmployees && schedule.status != 'cancelled')
                    TextButton.icon(
                      onPressed: () =>
                          _openEditor(context, _cubit.state, schedule),
                      icon: const AppIcon(AppIcons.edit01, size: 16),
                      label: Text(S.edit),
                    ),
                  if (schedule.status == 'draft')
                    TextButton(
                      onPressed: () => _changeStatus(schedule, 'published'),
                      child: Text(S.hrPublishSchedule),
                    ),
                  if (schedule.status == 'published')
                    TextButton(
                      onPressed: () => _changeStatus(schedule, 'cancelled'),
                      child: Text(S.hrCancelSchedule),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _changeStatus(HrSchedule schedule, String status) async {
    await _cubit.setStatus(
      id: schedule.id,
      status: status,
      from: _from,
      to: _to,
      canReadEmployees: widget.canReadEmployees,
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    HrSchedulesState state, [
    HrSchedule? schedule,
  ]) async {
    if (!widget.canManage || !widget.canReadEmployees) return;
    if (_to.isBefore(_from) || _to.difference(_from).inDays > 62) {
      _showMessage(S.hrScheduleInvalidRange);
      return;
    }
    final data = await showDialog<_HrScheduleDraft>(
      context: context,
      builder: (context) => _HrScheduleDialog(
        branches: state.branches,
        employees: state.employees,
        schedule: schedule,
      ),
    );
    if (data == null || !mounted) return;
    await _cubit.save(
      staffId: data.staffId,
      branchId: data.branchId,
      start: data.start,
      end: data.end,
      breakMinutes: data.breakMinutes,
      status: data.status,
      note: data.note,
      id: schedule?.id,
      from: _from,
      to: _to,
      canReadEmployees: widget.canReadEmployees,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _time(DateTime date) =>
      '${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';
  String _statusLabel(String status) => switch (status) {
    'published' => S.hrSchedulePublished,
    'cancelled' => S.hrScheduleCancelled,
    _ => S.hrScheduleDraft,
  };
}

class _AccessNote extends StatelessWidget {
  const _AccessNote({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColor.adminAccentSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(message),
  );
}

class _HrScheduleDraft {
  const _HrScheduleDraft({
    required this.staffId,
    required this.branchId,
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.status,
    required this.note,
  });
  final String staffId;
  final String branchId;
  final DateTime start;
  final DateTime end;
  final int breakMinutes;
  final String status;
  final String note;
}

class _HrScheduleDialog extends StatefulWidget {
  const _HrScheduleDialog({
    required this.branches,
    required this.employees,
    this.schedule,
  });
  final List<HrScheduleBranch> branches;
  final List<HrScheduleEmployee> employees;
  final HrSchedule? schedule;
  @override
  State<_HrScheduleDialog> createState() => _HrScheduleDialogState();
}

class _HrScheduleDialogState extends State<_HrScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _staffId = widget.schedule?.staffId;
  late String? _branchId = widget.schedule?.branchId;
  late DateTime _start = widget.schedule?.start.toLocal() ?? DateTime.now();
  late DateTime _end =
      widget.schedule?.end.toLocal() ??
      DateTime.now().add(const Duration(hours: 8));
  late String _status = widget.schedule?.status == 'published'
      ? 'published'
      : 'draft';
  late final TextEditingController _breakController = TextEditingController(
    text: '${widget.schedule?.breakMinutes ?? 0}',
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.schedule?.note ?? '',
  );

  @override
  void dispose() {
    _breakController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.schedule == null ? S.hrCreateSchedule : S.hrEditSchedule,
    ),
    content: SizedBox(
      width: 500,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _staffId,
                isExpanded: true,
                decoration: InputDecoration(labelText: S.staffLabel),
                items: [
                  for (final employee in widget.employees)
                    DropdownMenuItem(
                      value: employee.id,
                      child: Text(employee.name),
                    ),
                ],
                onChanged: (value) => setState(() => _staffId = value),
                validator: (value) => value == null ? S.requiredField : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                isExpanded: true,
                decoration: InputDecoration(labelText: S.branchLabel),
                items: [
                  for (final branch in widget.branches)
                    DropdownMenuItem(
                      value: branch.id,
                      child: Text(
                        AppLocale.instance.isArabic
                            ? (branch.nameAr.isEmpty
                                  ? branch.nameEn
                                  : branch.nameAr)
                            : (branch.nameEn.isEmpty
                                  ? branch.nameAr
                                  : branch.nameEn),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _branchId = value),
                validator: (value) => value == null ? S.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              _dateTimeRow(
                S.hrShiftStart,
                _start,
                (value) => setState(() => _start = value),
              ),
              _dateTimeRow(
                S.hrShiftEnd,
                _end,
                (value) => setState(() => _end = value),
              ),
              TextFormField(
                controller: _breakController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: S.hrBreakMinutes),
                validator: (value) {
                  final minutes = int.tryParse(value ?? '');
                  return minutes == null || minutes < 0 || minutes > 240
                      ? S.requiredField
                      : null;
                },
              ),
              TextFormField(
                controller: _noteController,
                maxLength: 500,
                decoration: InputDecoration(labelText: S.hrScheduleNote),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(labelText: S.status),
                items: [
                  DropdownMenuItem(
                    value: 'draft',
                    child: Text(S.hrScheduleDraft),
                  ),
                  DropdownMenuItem(
                    value: 'published',
                    child: Text(S.hrSchedulePublished),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? 'draft'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(S.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(S.save)),
    ],
  );

  Widget _dateTimeRow(
    String label,
    DateTime value,
    ValueChanged<DateTime> changed,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
    ),
    trailing: IconButton(
      tooltip: label,
      icon: const AppIcon(AppIcons.calendar01, size: 18),
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null) return;
        changed(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
    ),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final end = _end;
    if (!end.isAfter(_start) || end.difference(_start).inHours > 24) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.hrScheduleInvalidRange)));
      return;
    }
    Navigator.pop(
      context,
      _HrScheduleDraft(
        staffId: _staffId!,
        branchId: _branchId!,
        start: _start,
        end: _end,
        breakMinutes: int.parse(_breakController.text),
        status: _status,
        note: _noteController.text.trim(),
      ),
    );
  }
}
