import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';

class ReservationFormPage extends StatefulWidget {
  const ReservationFormPage({super.key});
  static const routeName = '/reservation-form';
  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final _repo = CustomerReservationRepository();
  String? _branchId;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  int _party = 2;
  String _type = 'table';
  final _note = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final client = SupabaseService.client;
      if (client == null) return;
      final rows = await client.from('branches').select('id,name_ar,name_en').eq('is_active', true).order('name_ar');
      final list = (rows as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _branches = list;
        if (_branches.isNotEmpty) _branchId = _branches.first['id']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_branchId == null) return;
    setState(() => _saving = true);
    try {
      final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      await _repo.create(
        branchId: _branchId!,
        reservedFor: dt,
        partySize: _party,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        reservationType: _type,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.myReservations)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _branchId,
            items: _branches
                .map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text((b['name_ar'] ?? b['name_en'] ?? '').toString())))
                .toList(),
            onChanged: (v) => setState(() => _branchId = v),
            decoration: const InputDecoration(labelText: 'Branch'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'table', child: Text('Table')),
              DropdownMenuItem(value: 'room', child: Text('Room')),
              DropdownMenuItem(value: 'event', child: Text('Event')),
              DropdownMenuItem(value: 'private', child: Text('Private')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'table'),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date: ${_date.toLocal().toString().split(' ').first}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Time: ${_time.format(context)}'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _party,
            items: List.generate(20, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) => setState(() => _party = v ?? 2),
            decoration: const InputDecoration(labelText: 'Party size'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note'), maxLines: 3),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saving ? null : _submit, child: _saving ? const CircularProgressIndicator() : const Text('Submit request')),
        ],
      ),
    );
  }
}
