import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';

class ReservationFormPage extends StatefulWidget {
  const ReservationFormPage({super.key});
  static const routeName = '/reservation-form';

  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final _note = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 20, minute: 0);
  int _party = 2;
  bool _saving = false;
  List<Map<String, dynamic>> _branches = const [];
  String? _branchId;
  bool _loadingBranches = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final c = SupabaseService.client;
      final rows = await c.from('branches').select('id,name_ar,name_en').eq('is_active', true);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(rows);
        _branchId = _branches.isNotEmpty ? _branches.first['id'] as String : null;
        _loadingBranches = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBranches = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _submit() async {
    if (_branchId == null) return;
    setState(() => _saving = true);
    try {
      final reservedFor = _combine(_date, _start);
      var requestedEndAt = _combine(_date, _end);
      if (!requestedEndAt.isAfter(reservedFor)) {
        requestedEndAt = requestedEndAt.add(const Duration(days: 1));
      }
      await CustomerReservationRepository().create(
        branchId: _branchId!,
        reservedFor: reservedFor,
        requestedEndAt: requestedEndAt,
        partySize: _party,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.reservationSubmitted)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.couldNotSubmitReservation)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          title: DesignText(
            S.newReservation,
            page: 'reservation_form',
            label: 'title',
          ),
        ),
        body: _loadingBranches
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: AppLayout.pageBody,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _branchId,
                    decoration: InputDecoration(labelText: S.branch),
                    isExpanded: true,
                    items: _branches
                        .map((b) => DropdownMenuItem<String>(
                              value: b['id'] as String,
                              child: Text(
                                (b['name_ar'] ?? b['name_en'] ?? '').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _branchId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.date),
                    subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.time),
                    subtitle: Text(
                      '${_start.format(context)} - ${_end.format(context)}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final s = await showTimePicker(context: context, initialTime: _start);
                      if (s == null || !mounted) return;
                      final e = await showTimePicker(context: context, initialTime: _end);
                      if (e == null) return;
                      setState(() {
                        _start = s;
                        _end = e;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    initialValue: _party,
                    decoration: InputDecoration(labelText: S.partySize),
                    items: List.generate(20, (i) => i + 1)
                        .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setState(() => _party = v ?? 2),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _note,
                    decoration: InputDecoration(labelText: S.reservationNote),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _saving || _branchId == null ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(S.submitReservation),
                  ),
                ],
              ),
      ),
    );
  }
}
