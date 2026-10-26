import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/tables/data/models/dining_enums.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';
import 'package:admin_app/features/tables/data/repositories/dining_tables_repository.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_cubit.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// Opens the booking editor. Returns true when the booking was saved.
Future<bool?> showDiningReservationDialog(
  BuildContext context, {
  required DiningTablesCubit cubit,
  required List<DiningTable> tables,
  DiningReservation? reservation,
  DiningTable? initialTable,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DiningReservationDialog(
      cubit: cubit,
      tables: tables,
      reservation: reservation,
      initialTable: initialTable,
    ),
  );
}

class _DiningReservationDialog extends StatefulWidget {
  const _DiningReservationDialog({
    required this.cubit,
    required this.tables,
    this.reservation,
    this.initialTable,
  });

  final DiningTablesCubit cubit;
  final List<DiningTable> tables;
  final DiningReservation? reservation;
  final DiningTable? initialTable;

  @override
  State<_DiningReservationDialog> createState() =>
      _DiningReservationDialogState();
}

class _DiningReservationDialogState extends State<_DiningReservationDialog> {
  static const _durations = <int>[30, 60, 90, 120, 180];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _party;
  late final TextEditingController _note;
  late DateTime _startsAt;
  late int _duration;
  String? _tableId;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.reservation != null;

  bool get _tableLocked =>
      widget.reservation?.status == DiningReservationStatus.seated;

  List<DiningTable> get _activeTables =>
      widget.tables.where((table) => table.isActive).toList(growable: false);

  /// Active tables plus the booked table itself, which may have been
  /// deactivated after the booking was taken.
  List<DiningTable> get _selectableTables {
    final active = _activeTables;
    final currentId = widget.reservation?.tableId;
    if (currentId == null || active.any((table) => table.id == currentId)) {
      return active;
    }
    for (final table in widget.tables) {
      if (table.id == currentId) {
        return [table, ...active];
      }
    }
    return active;
  }

  DiningTable? _firstTable([int? partySize]) {
    for (final table in _activeTables) {
      if (partySize == null || table.capacity >= partySize) return table;
    }
    return _activeTables.isEmpty ? null : _activeTables.first;
  }

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _name = TextEditingController(text: reservation?.customerName ?? '');
    _phone = TextEditingController(text: reservation?.customerPhone ?? '');
    _party = TextEditingController(text: '${reservation?.partySize ?? 2}');
    _note = TextEditingController(text: reservation?.note ?? '');
    _duration = reservation?.durationMinutes ?? 90;
    if (!_durations.contains(_duration)) {
      _duration = _durations.reduce(
        (a, b) => (a - _duration).abs() <= (b - _duration).abs() ? a : b,
      );
    }

    final now = DateTime.now();
    final fallback = now.add(const Duration(hours: 1));
    _startsAt = reservation?.reservedFor?.toLocal() ?? fallback;
    if (_startsAt.isBefore(now)) _startsAt = fallback;

    final preferred =
        reservation?.tableId ??
        widget.initialTable?.id ??
        _firstTable(reservation?.partySize ?? 2)?.id;
    _tableId = _selectableTables.any((table) => table.id == preferred)
        ? preferred
        : (_selectableTables.isNotEmpty ? _selectableTables.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _party.dispose();
    _note.dispose();
    super.dispose();
  }

  DiningTable? get _selectedTable {
    final id = _tableId;
    for (final table in _selectableTables) {
      if (table.id == id) return table;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final initial = _startsAt.isBefore(firstDate) ? firstDate : _startsAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final table = _selectedTable;
    if (table == null) {
      setState(() => _error = S.reservationTableRequired);
      return;
    }
    if (_startsAt.isBefore(
      DateTime.now().subtract(const Duration(minutes: 5)),
    )) {
      setState(() => _error = S.reservationDatePast);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await widget.cubit.saveReservation(
      DiningReservationDraft(
        id: widget.reservation?.id,
        tableId: table.id,
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
        partySize: int.tryParse(_party.text.trim()) ?? 1,
        reservedFor: _startsAt,
        durationMinutes: _duration,
        note: _note.text.trim(),
      ),
    );
    if (!mounted) return;
    if (outcome == DiningReservationSaveOutcome.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = diningReservationSaveErrorMessage(outcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(560.0, size.width - 32);
    final height = min(660.0, size.height * .92);

    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDialogHeader(
                title: _editing ? S.editReservation : S.addReservation,
                subtitle: S.reservationEditorSubtitle,
                onClose: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 120,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? S.reservationGuestNameRequired
                              : null,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.reservationGuestName,
                            hint: S.reservationGuestNameHint,
                            required: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phone,
                                enabled: !_saving,
                                maxLength: 40,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                style: TextStyle(
                                  color: adminBodyColor(theme),
                                  fontSize: AppFontSizes.size11_5,
                                ),
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.reservationPhone,
                                  hint: S.reservationPhoneHint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _party,
                                enabled: !_saving,
                                maxLength: 2,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  final count = int.tryParse(
                                    (value ?? '').trim(),
                                  );
                                  if (count == null ||
                                      count < 1 ||
                                      count > 40) {
                                    return S.reservationPartyRange;
                                  }
                                  final table = _selectedTable;
                                  if (table != null && count > table.capacity) {
                                    return S.reservationPartyTooLarge;
                                  }
                                  return null;
                                },
                                style: TextStyle(
                                  color: adminBodyColor(theme),
                                  fontSize: AppFontSizes.size11_5,
                                ),
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.reservationParty,
                                  hint: '2',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        DropdownButtonFormField<String>(
                          initialValue: _tableId,
                          isExpanded: true,
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.reservationTable,
                            hint: S.reservationTableRequired,
                          ),
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11,
                          ),
                          dropdownColor: theme.colorScheme.surface,
                          items: [
                            for (final table in _selectableTables)
                              DropdownMenuItem(
                                value: table.id,
                                child: Text(
                                  '${table.name} • ${diningAreaLabel(table.area)} • '
                                  '${S.tableCapacity(table.capacity)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: adminBodyColor(theme),
                                    fontSize: AppFontSizes.size11,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: _saving || _tableLocked
                              ? null
                              : (value) => setState(() {
                                  _tableId = value;
                                  _formKey.currentState?.validate();
                                }),
                          validator: (value) =>
                              value == null ? S.reservationTableRequired : null,
                        ),
                        if (_tableLocked) ...[
                          const SizedBox(height: 6),
                          Text(
                            S.reservationSeatedTableLocked,
                            style: TextStyle(
                              color: adminMutedColor(theme),
                              fontSize: AppFontSizes.size9,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: S.reservationDate,
                                value: localizedDate(_startsAt),
                                icon: HugeIcons.strokeRoundedCalendar01,
                                onTap: _saving ? null : _pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PickerField(
                                label: S.reservationTime,
                                value: localizedTime(_startsAt),
                                icon: HugeIcons.strokeRoundedClock01,
                                onTap: _saving ? null : _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _duration,
                          isExpanded: true,
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.reservationDuration,
                            hint: '',
                          ),
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11,
                          ),
                          dropdownColor: theme.colorScheme.surface,
                          items: [
                            for (final minutes in _durations)
                              DropdownMenuItem(
                                value: minutes,
                                child: Text(
                                  _durationLabelFor(minutes),
                                  style: TextStyle(
                                    color: adminBodyColor(theme),
                                    fontSize: AppFontSizes.size11,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _duration = value);
                                },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _note,
                          enabled: !_saving,
                          maxLength: 500,
                          maxLines: 2,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.reservationNote,
                            hint: S.reservationNoteHint,
                          ),
                        ),
                        if (_selectableTables.isEmpty) ...[
                          const SizedBox(height: 10),
                          AdminErrorBanner(message: S.tablesEmptyHint),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AdminErrorBanner(message: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              AdminDialogFooter(
                saving: _saving,
                onCancel: () => Navigator.of(context).maybePop(),
                onSave: _selectableTables.isEmpty ? () {} : _save,
                saveKey: const Key('dining-reservation-save'),
                saveLabel: S.save,
                savingLabel: S.saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _durationLabelFor(int minutes) => switch (minutes) {
    30 => S.reservationDuration30,
    60 => S.reservationDuration60,
    120 => S.reservationDuration120,
    180 => S.reservationDuration180,
    _ => S.reservationDuration90,
  };
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: adminControlBorderColor(theme)),
          ),
          child: Row(
            children: [
              HugeIcon(icon: icon, size: 15, color: adminMutedColor(theme)),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
