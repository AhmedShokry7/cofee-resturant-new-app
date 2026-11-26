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

  @override
  void initState() {
    super.initState();
    _loadBranches();
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
        _branchId = _branches.isEmpty ? null : _branches.first['id'] as String;
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
      '${branch['name_ar'] ?? branch['name_en'] ?? ''}';

  Future<void> _submit() async {
    final branch = _branchId;
    if (branch == null) return;
    if (_occasion == 'other' && _occasionName.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب اسم المناسبة أولاً.')));
      return;
    }
    var startAt = _at(_start), endAt = _at(_end);
    if (!endAt.isAfter(startAt)) endAt = endAt.add(const Duration(days: 1));
    final duration = endAt.difference(startAt);
    if (!startAt.isAfter(DateTime.now()) ||
        duration.inMinutes < 30 ||
        duration.inMinutes > 480) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر موعداً مستقبلياً ومدة بين 30 دقيقة و8 ساعات.'),
        ),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب المناسبة. سيظهر الحجز بعد قبول عرض الفرع.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إرسال الطلب. تحقق من البيانات وحاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
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
        title: const DesignText(
          'طلب مناسبة خاصة',
          page: 'event_request_form',
          label: 'title',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                child: const Text('تعذر تحميل الفروع · إعادة المحاولة'),
              ),
            )
          : _branches.isEmpty
          ? const Center(child: Text('لا توجد فروع متاحة لطلب المناسبة.'))
          : ListView(
              padding: AppLayout.pageBody,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'أرسل تفاصيل مناسبتك، وسيراجعها الفرع ويرسل لك السعر والمكان والموعد المقترح. لن يصبح الحجز مؤكداً إلا بعد موافقتك على العرض.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<String>(
                  initialValue: _branchId,
                  decoration: const InputDecoration(labelText: 'الفرع'),
                  items: _branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(_branchName(b)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _branchId = v),
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<String>(
                  initialValue: _occasion,
                  decoration: const InputDecoration(labelText: 'نوع المناسبة'),
                  items: const [
                    DropdownMenuItem(
                      value: 'birthday',
                      child: Text('عيد ميلاد'),
                    ),
                    DropdownMenuItem(
                      value: 'graduation',
                      child: Text('حفل تخرج'),
                    ),
                    DropdownMenuItem(
                      value: 'family_gathering',
                      child: Text('تجمع عائلي'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('مناسبة أخرى'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _occasion = v ?? 'other'),
                ),
                if (_occasion == 'other') ...[
                  const SizedBox(height: AppSizes.px12),
                  TextField(
                    controller: _occasionName,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم المناسبة',
                      hintText: 'مثال: حفل زفاف أو افتتاح',
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<String>(
                  initialValue: _space,
                  decoration: const InputDecoration(
                    labelText: 'المكان المطلوب',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'any',
                      child: Text('غرفة أو طاولة حسب المتاح'),
                    ),
                    DropdownMenuItem(value: 'room', child: Text('غرفة خاصة')),
                    DropdownMenuItem(value: 'table', child: Text('طاولة')),
                  ],
                  onChanged: (v) => setState(() => _space = v ?? 'any'),
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<int>(
                  initialValue: _reminderMinutes,
                  decoration: const InputDecoration(
                    labelText: 'ذكرني قبل المناسبة',
                  ),
                  items: const [
                    DropdownMenuItem(value: 60, child: Text('بساعة')),
                    DropdownMenuItem(value: 180, child: Text('بـ 3 ساعات')),
                    DropdownMenuItem(value: 1440, child: Text('بيوم')),
                  ],
                  onChanged: (value) =>
                      setState(() => _reminderMinutes = value ?? 1440),
                ),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'سيصلك التذكير بعد تأكيد الحجز، ويظهر أيضًا في الصفحة الرئيسية.',
                      style: TextStyle(fontSize: AppFontSizes.size12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.px12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ المناسبة'),
                  subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
                  trailing: const Icon(AppIcons.calendar),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _timePicker(
                        'من',
                        _start,
                        (v) => setState(() => _start = v),
                      ),
                    ),
                    const SizedBox(width: AppSizes.px12),
                    Expanded(
                      child: _timePicker(
                        'إلى',
                        _end,
                        (v) => setState(() => _end = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.px12),
                DropdownButtonFormField<int>(
                  initialValue: _guests,
                  decoration: const InputDecoration(labelText: 'عدد الضيوف'),
                  items: List.generate(39, (i) => i + 2)
                      .map(
                        (n) =>
                            DropdownMenuItem(value: n, child: Text('$n ضيف')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _guests = v ?? 2),
                ),
                const SizedBox(height: AppSizes.px12),
                TextField(
                  controller: _services,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'الخدمات المطلوبة (اختياري)',
                    hintText: 'مثل: تزيين، كيكة، تجهيزات خاصة',
                  ),
                ),
                const SizedBox(height: AppSizes.px8),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات للفرع (اختياري)',
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
                  label: const Text('إرسال طلب المناسبة'),
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
