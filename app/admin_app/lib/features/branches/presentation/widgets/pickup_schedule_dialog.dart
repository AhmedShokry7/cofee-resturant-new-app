import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/services/supabase_service.dart';

Future<void> showPickupScheduleDialog({
  required BuildContext context,
  required AdminBranch branch,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PickupScheduleDialog(branch: branch),
);

class _PickupScheduleDialog extends StatefulWidget {
  const _PickupScheduleDialog({required this.branch});
  final AdminBranch branch;
  @override
  State<_PickupScheduleDialog> createState() => _PickupScheduleDialogState();
}

class _PickupScheduleDialogState extends State<_PickupScheduleDialog> {
  List<Map<String, dynamic>> windows = [];
  List<Map<String, dynamic>> exceptions = [];
  bool loading = true;
  String? error;
  final timeZone = TextEditingController(text: 'Asia/Riyadh');

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await SupabaseService.client.rpc('admin_pickup_schedule', params: {'p_branch': widget.branch.id});
      final data = Map<String, dynamic>.from(result as Map);
      timeZone.text = '${data['time_zone'] ?? 'Asia/Riyadh'}';
      windows = (data['windows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      exceptions = (data['exceptions'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      error = S.couldNotLoadDashboard;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { timeZone.dispose(); super.dispose(); }

  Future<void> saveTimeZone() async {
    try {
      await SupabaseService.client.rpc('admin_set_branch_time_zone', params: {'p_branch': widget.branch.id, 'p_time_zone': timeZone.text.trim()});
      if (mounted) setState(() => error = null);
    } catch (_) { if (mounted) setState(() => error = S.pickupSaveFailed); }
  }

  Future<void> editWindow([Map<String, dynamic>? window]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WindowForm(window: window),
    );
    if (data == null) return;
    try {
      await SupabaseService.client.rpc('admin_save_pickup_window', params: {
        'p_id': data['id'], 'p_branch': widget.branch.id, 'p_weekday': data['weekday'],
        'p_opens': data['opens'], 'p_closes': data['closes'], 'p_slot_minutes': data['slot'],
        'p_capacity': data['capacity'], 'p_prep_minutes': data['prep'], 'p_enabled': data['enabled'],
      });
      await load();
    } catch (_) { if (mounted) setState(() => error = S.pickupSaveFailed); }
  }

  Future<void> addException() async {
    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _ExceptionForm());
    if (data == null) return;
    try {
      await SupabaseService.client.rpc('admin_save_pickup_exception', params: {
        'p_id': null, 'p_branch': widget.branch.id, 'p_date': data['date'], 'p_closed': data['closed'],
        'p_opens': data['opens'], 'p_closes': data['closes'], 'p_slot_minutes': data['slot'], 'p_capacity': data['capacity'],
      });
      await load();
    } catch (_) { if (mounted) setState(() => error = S.pickupSaveFailed); }
  }

  Future<void> delete(String rpc, String id) async {
    try {
      await SupabaseService.client.rpc(rpc, params: {'p_id': id, 'p_branch': widget.branch.id});
      await load();
    } catch (_) { if (mounted) setState(() => error = S.pickupSaveFailed); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${S.pickupScheduleTitle} • ${widget.branch.nameFor(AppLocale.instance.language)}'),
    content: SizedBox(width: 620, child: loading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        Row(children: [Expanded(child: TextField(controller: timeZone, decoration: InputDecoration(labelText: S.pickupTimeZone))), IconButton(onPressed: saveTimeZone, icon: const Icon(Icons.save_outlined))]),
        Row(children: [Expanded(child: Text(S.pickupWindows, style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => editWindow(), icon: const Icon(Icons.add))]),
        if (windows.isEmpty) Text(S.pickupNoSchedule),
        for (final w in windows) ListTile(
          dense: true,
          title: Text('${S.pickupWeekday((w['weekday'] as num).toInt())}  ${w['opens_at']}–${w['closes_at']}'),
          subtitle: Text('${w['slot_minutes']} min • ${w['capacity']} / slot • prep ${w['prep_minutes']} min${w['enabled'] == true ? '' : ' • ${S.inactive}'}'),
          trailing: Wrap(children: [IconButton(onPressed: () => editWindow(w), icon: const Icon(Icons.edit)), IconButton(onPressed: () => delete('admin_delete_pickup_window', '${w['id']}'), icon: const Icon(Icons.delete_outline))]),
        ),
        const Divider(),
        Row(children: [Expanded(child: Text(S.pickupExceptions, style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: addException, icon: const Icon(Icons.add))]),
        if (exceptions.isEmpty) Text(S.pickupNoSchedule),
        for (final e in exceptions) ListTile(
          dense: true,
          title: Text('${e['exception_date']} • ${e['closed'] == true ? S.pickupClosed : '${e['opens_at']}–${e['closes_at']}'}'),
          subtitle: e['closed'] == true ? null : Text('${e['slot_minutes'] ?? 15} min • ${e['capacity'] ?? 8} / slot'),
          trailing: IconButton(onPressed: () => delete('admin_delete_pickup_exception', '${e['id']}'), icon: const Icon(Icons.delete_outline)),
        ),
      ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(S.close))],
  );
}

class _WindowForm extends StatefulWidget {
  const _WindowForm({this.window});
  final Map<String, dynamic>? window;
  @override
  State<_WindowForm> createState() => _WindowFormState();
}

class _WindowFormState extends State<_WindowForm> {
  late int weekday = (widget.window?['weekday'] as num?)?.toInt() ?? 0;
  late TimeOfDay opens = _time(widget.window?['opens_at']?.toString()) ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay closes = _time(widget.window?['closes_at']?.toString()) ?? const TimeOfDay(hour: 22, minute: 0);
  late final slot = TextEditingController(text: '${widget.window?['slot_minutes'] ?? 15}');
  late final capacity = TextEditingController(text: '${widget.window?['capacity'] ?? 8}');
  late final prep = TextEditingController(text: '${widget.window?['prep_minutes'] ?? 15}');
  bool enabled = true;
  static TimeOfDay? _time(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }
  String _formatted(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';
  Future<TimeOfDay?> _pick(TimeOfDay initial) => showTimePicker(context: context, initialTime: initial);
  @override
  void initState() { super.initState(); enabled = widget.window?['enabled'] as bool? ?? true; }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.pickupAddWindow),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<int>(initialValue: weekday, items: [for (var d=0; d<7; d++) DropdownMenuItem(value:d, child:Text(S.pickupWeekday(d)))], onChanged: (v) => setState(() => weekday = v ?? 0)),
      Row(children: [
        Expanded(child: TextButton(
          onPressed: () async {
            final t = await _pick(opens);
            if (t != null) setState(() => opens = t);
          },
          child: Text(opens.format(context)),
        )),
        Expanded(child: TextButton(
          onPressed: () async {
            final t = await _pick(closes);
            if (t != null) setState(() => closes = t);
          },
          child: Text(closes.format(context)),
        )),
      ]),
      TextField(controller: slot, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Slot minutes')),
      TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity per slot')),
      TextField(controller: prep, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preparation minutes')),
      SwitchListTile(value: enabled, onChanged: (v)=>setState(()=>enabled=v), title: Text(S.active)),
    ])),
    actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text(S.cancel)), FilledButton(onPressed: () {
      final s=int.tryParse(slot.text), c=int.tryParse(capacity.text), p=int.tryParse(prep.text);
      if(s==null||c==null||p==null||s<5||s>240||c<1||c>500||p<0||p>480||opens.hour*60+opens.minute>=closes.hour*60+closes.minute) return;
      Navigator.pop(context, {'id':widget.window?['id'], 'weekday':weekday, 'opens':_formatted(opens), 'closes':_formatted(closes), 'slot':s, 'capacity':c, 'prep':p, 'enabled':enabled});
    }, child: Text(S.pickupSave))],
  );
}

class _ExceptionForm extends StatefulWidget {
  const _ExceptionForm();
  @override
  State<_ExceptionForm> createState() => _ExceptionFormState();
}

class _ExceptionFormState extends State<_ExceptionForm> {
  DateTime date = DateUtils.dateOnly(DateTime.now());
  bool closed = true;
  TimeOfDay opens = const TimeOfDay(hour: 9, minute: 0), closes = const TimeOfDay(hour: 18, minute: 0);
  final slot = TextEditingController(text: '15'), capacity = TextEditingController(text: '8');
  String _time(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.pickupAddException),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextButton(onPressed: () async { final d=await showDatePicker(context:context, initialDate:date, firstDate:DateUtils.dateOnly(DateTime.now()), lastDate:DateTime.now().add(const Duration(days:365))); if(d!=null)setState(()=>date=d); }, child: Text(MaterialLocalizations.of(context).formatFullDate(date))),
      SwitchListTile(value: closed, onChanged:(v)=>setState(()=>closed=v), title:Text(S.pickupClosed)),
      if(!closed) ...[
        Row(children: [
          Expanded(child: TextButton(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: opens);
              if (t != null) setState(() => opens = t);
            },
            child: Text(opens.format(context)),
          )),
          Expanded(child: TextButton(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: closes);
              if (t != null) setState(() => closes = t);
            },
            child: Text(closes.format(context)),
          )),
        ]),
        TextField(controller:slot,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Slot minutes')),
        TextField(controller:capacity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Capacity per slot')),
      ],
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(S.cancel)),FilledButton(onPressed:(){
      final s=int.tryParse(slot.text),c=int.tryParse(capacity.text);
      if(!closed&&(s==null||c==null||s<5||s>240||c<1||c>500||opens.hour*60+opens.minute>=closes.hour*60+closes.minute))return;
      Navigator.pop(context,{'date':'${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}','closed':closed,'opens':closed?null:_time(opens),'closes':closed?null:_time(closes),'slot':closed?null:s,'capacity':closed?null:c});
    },child:Text(S.pickupSave))],
  );
}
