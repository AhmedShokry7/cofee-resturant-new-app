import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:material_ui/material_ui.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class EventRequestFormPage extends StatefulWidget {
  const EventRequestFormPage({super.key});
  static const routeName = '/event-request-form';

  @override
  State<EventRequestFormPage> createState() => _EventRequestFormPageState();
}

class _EventRequestFormPageState extends State<EventRequestFormPage> {
  final _note = TextEditingController();
  final _services = TextEditingController();
  final _occasionName = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 21, minute: 0);
  int _guests = 10;
  String _occasion = 'birthday';
  int _reminderMinutes = 1440;
  String _space = 'any';
  String? _branchId;
  List<Map<String, dynamic>> _branches = const [];
  bool _loading = true;
  bool _branchLoadFailed = false;
  bool _saving = false;

  SharedPreferences? _prefs;
  String? _draftKey;
  bool _submitted = false;
  Timer? _debounce;

  Future<void> _initialize() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        _draftKey = 'event_request_draft_v1_$userId';
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        _prefs = prefs;
        final raw = prefs.getString(_draftKey!);
        if (raw != null) {
          final draft = jsonDecode(raw) as Map<String, dynamic>;
          _note.text = draft['note'] as String? ?? '';
          _services.text = draft['services'] as String? ?? '';
          _occasionName.text = draft['name'] as String? ?? '';
          _branchId = draft['branch'] as String?;
          final occasion = draft['occasion'];
          if ([
            'birthday',
            'graduation',
            'family_gathering',
            'other',
          ].contains(occasion))
            _occasion = occasion as String;
          final space = draft['space'];
          if (['any', 'room', 'table'].contains(space))
            _space = space as String;
          final reminder = draft['reminder'];
          if ([60, 180, 1440].contains(reminder))
            _reminderMinutes = reminder as int;
          _guests = ((draft['guests'] as int?) ?? 10).clamp(2, 40);
          final date = DateTime.tryParse(draft['date'] as String? ?? '');
          if (date != null &&
              !date.isBefore(DateUtils.dateOnly(DateTime.now())) &&
              date.isBefore(DateTime.now().add(const Duration(days: 366))))
            _date = date;
          TimeOfDay restoreTime(String key, TimeOfDay fallback) {
            final minutes = draft[key];
            if (minutes is! int || minutes < 0 || minutes >= 1440)
              return fallback;
            return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
          }

          _start = restoreTime('start', _start);
          _end = restoreTime('end', _end);
        }
      }
    } catch (_) {
      /* A draft is optional. */
    }
    if (mounted) await _loadBranches();
  }

  void _saveDraft() {
    if (_submitted || _loading || _prefs == null || _draftKey == null) return;
    unawaited(
      _prefs!.setString(
        _draftKey!,
        jsonEncode({
          'note': _note.text,
          'services': _services.text,
          'name': _occasionName.text,
          'branch': _branchId,
          'occasion': _occasion,
          'space': _space,
          'guests': _guests,
          'reminder': _reminderMinutes,
          'date': _date.toIso8601String(),
          'start': _start.hour * 60 + _start.minute,
          'end': _end.hour * 60 + _end.minute,
        }),
      ),
    );
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _saveDraft);
  }

  @override
  void initState() {
    super.initState();
    _initialize();
    for (final controller in [_note, _services, _occasionName]) {
      controller.addListener(_changed);
    }
  }

  Future<void> _loadBranches() async {
    try {
      final rows = await SupabaseService.client
          .from('branches')
          .select('id,name_ar,name_en')
          .eq('is_active', true);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(rows);
        if (!_branches.any((b) => b['id'] == _branchId))
          _branchId = _branches.isEmpty
              ? null
              : _branches.first['id'] as String;
        _loading = false;
        _branchLoadFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _branchLoadFailed = true;
        });
      }
    }
  }

  DateTime _at(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
  String _branchName(Map<String, dynamic> branch) =>
      '${branch[AppLocale.instance.isArabic ? 'name_ar' : 'name_en'] ?? branch['name_ar'] ?? branch['name_en'] ?? ''}';

  Future<void> _submit() async {
    final branch = _branchId;
    if (branch == null) return;
    if (_occasion == 'other' && _occasionName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.eventFormNameRequired)));
      return;
    }
    var startAt = _at(_start), endAt = _at(_end);
    if (!endAt.isAfter(startAt)) endAt = endAt.add(const Duration(days: 1));
    final duration = endAt.difference(startAt);
    if (!startAt.isAfter(DateTime.now()) ||
        duration.inMinutes < 30 ||
        duration.inMinutes > 480) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.eventFormInvalidTime)));
      return;
    }
    setState(() => _saving = true);
    try {
      await CustomerReservationRepository().createEventRequest(
        branchId: branch,
        occasionType: _occasion,
        occasionName: _occasion == 'other' ? _occasionName.text : null,
        startAt: startAt,
        endAt: endAt,
        guestCount: _guests,
        spaceType: _space,
        services: _services.text,
        note: _note.text,
        reminderMinutes: _reminderMinutes,
      );
      _submitted = true;
      _debounce?.cancel();
      if (_draftKey != null) unawaited(_prefs?.remove(_draftKey!));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.eventFormSubmitted)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.eventFormSubmitFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _saveDraft();
    _note.dispose();
    _services.dispose();
    _occasionName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthGuard(
    child: Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: DesignText(
          S.eventFormTitle,
          page: 'event_request_form',
          label: 'title',
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _branchLoadFailed
          ? Center(
              child: CustomFilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _branchLoadFailed = false;
                  });
                  _loadBranches();
                },
                child: DesignText(
                  S.eventFormRetryBranches,
                  page: 'event_request_form',
                  label: 'retryBranches',
                ),
              ),
            )
          : _branches.isEmpty
          ? Center(child: Text(S.eventFormNoBranches))
          : ListView(
              padding: AppLayout.pageBody,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      S.eventFormDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<String>(
                  initialValue: _branchId,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormBranch,
                      page: 'event_request_form',
                      label: 'branch',
                    ),
                  ),
                  items: _branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(_branchName(b)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _branchId = v;
                    _changed();
                  }),
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<String>(
                  initialValue: _occasion,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormOccasion,
                      page: 'event_request_form',
                      label: 'occasion',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'birthday',
                      child: Text(S.eventFormBirthday),
                    ),
                    DropdownMenuItem(
                      value: 'graduation',
                      child: Text(S.eventFormGraduation),
                    ),
                    DropdownMenuItem(
                      value: 'family_gathering',
                      child: Text(S.eventFormFamily),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(S.eventFormOther),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _occasion = v ?? 'other';
                    _changed();
                  }),
                ),
                if (_occasion == 'other') ...[
                  const SizedBox(height: AppSizes.px12),
                  TextField(
                    controller: _occasionName,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      label: DesignText(
                        S.eventFormOccasionName,
                        page: 'event_request_form',
                        label: 'occasionName',
                      ),
                      hintText: S.eventFormOccasionHint,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<String>(
                  initialValue: _space,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormSpace,
                      page: 'event_request_form',
                      label: 'space',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: 'any', child: Text(S.eventFormAny)),
                    DropdownMenuItem(
                      value: 'room',
                      child: Text(S.eventFormRoom),
                    ),
                    DropdownMenuItem(
                      value: 'table',
                      child: Text(S.eventFormTable),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _space = v ?? 'any';
                    _changed();
                  }),
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<int>(
                  initialValue: _reminderMinutes,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormReminder,
                      page: 'event_request_form',
                      label: 'reminder',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: 60, child: Text(S.eventFormHour)),
                    DropdownMenuItem(
                      value: 180,
                      child: Text(S.eventFormThreeHours),
                    ),
                    DropdownMenuItem(value: 1440, child: Text(S.eventFormDay)),
                  ],
                  onChanged: (value) => setState(() {
                    _reminderMinutes = value ?? 1440;
                    _changed();
                  }),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      S.eventFormReminderHint,
                      style: TextStyle(fontSize: AppFontSizes.size12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.px12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: DesignText(
                    S.eventFormEventDate,
                    page: 'event_request_form',
                    label: 'eventDate',
                  ),
                  subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
                  trailing: const Icon(AppIcons.calendar),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null)
                      setState(() {
                        _date = d;
                        _changed();
                      });
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        S.eventFormFrom,
                        _start,
                        (v) => setState(() {
                          _start = v;
                          _changed();
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSizes.px12),
                    Expanded(
                      child: _timePicker(
                        S.eventFormTo,
                        _end,
                        (v) => setState(() {
                          _end = v;
                          _changed();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<int>(
                  initialValue: _guests,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormGuests,
                      page: 'event_request_form',
                      label: 'guests',
                    ),
                  ),
                  items: List.generate(39, (i) => i + 2)
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text(S.eventFormGuestCount(n)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _guests = v ?? 2;
                    _changed();
                  }),
                ),
                const SizedBox(height: AppSizes.px12),
                TextField(
                  controller: _services,
                  maxLength: 500,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormServices,
                      page: 'event_request_form',
                      label: 'services',
                    ),
                    hintText: S.eventFormServicesHint,
                  ),
                ),
                const SizedBox(height: AppSizes.px8),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    label: DesignText(
                      S.eventFormNote,
                      page: 'event_request_form',
                      label: 'note',
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.px20),
                CustomFilledButton.icon(
                  onPressed: _saving || _branches.isEmpty ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: AppSizes.px18,
                          height: AppSizes.px18,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSizes.px2,
                          ),
                        )
                      : const Icon(AppIcons.sent),
                  label: DesignText(
                    S.eventFormSendRequest,
                    page: 'event_request_form',
                    label: 'sendRequest',
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _timePicker(
    String label,
    TimeOfDay value,
    ValueChanged<TimeOfDay> onChanged,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value.format(context)),
    trailing: const Icon(AppIcons.clock),
    onTap: () async {
      final t = await showTimePicker(context: context, initialTime: value);
      if (t != null) onChanged(t);
    },
  );
}
