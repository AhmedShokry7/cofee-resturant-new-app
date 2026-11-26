import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

typedef OfferEvent = Future<bool> Function({
  required String id,
  required double amount,
  required List<String> spaceIds,
  required DateTime startAt,
  required DateTime endAt,
  String? note,
});
typedef RejectEvent = Future<bool> Function(String id);
typedef DeleteEvent = Future<bool> Function(String id);

class CustomerEventRequestsPanel extends StatelessWidget {
  const CustomerEventRequestsPanel({
    super.key,
    required this.requests,
    required this.tables,
    required this.canManage,
    required this.onOffer,
    required this.onReject,
    this.onDelete,
  });

  final List<Map<String, dynamic>> requests;
  final List<DiningTable> tables;
  final bool canManage;
  final OfferEvent onOffer;
  final RejectEvent onReject;
  final DeleteEvent? onDelete;

  @override
  Widget build(BuildContext context) {
    final active = requests.toList()
      ..sort((left, right) {
        final leftTime = DateTime.tryParse(
          '${left['quoted_start_at'] ?? left['preferred_start_at'] ?? ''}',
        );
        final rightTime = DateTime.tryParse(
          '${right['quoted_start_at'] ?? right['preferred_start_at'] ?? ''}',
        );
        if (leftTime == null) return rightTime == null ? 0 : 1;
        if (rightTime == null) return -1;
        return leftTime.compareTo(rightTime);
      });
    if (active.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.gift,
        message: S.eventRequestsEmpty,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1480
            ? 4
            : constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          itemCount: active.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: columns == 1 ? 400 : 420,
          ),
          itemBuilder: (context, index) =>
              _requestCard(context, active[index]),
        );
      },
    );
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final type = switch ('${row['occasion_type']}') {
      'birthday' => 'عيد ميلاد',
      'graduation' => 'حفل تخرج',
      'family_gathering' => 'تجمع عائلي',
      _ => '${row['occasion_name'] ?? ''}'.trim().isEmpty
          ? 'مناسبة خاصة'
          : '${row['occasion_name']}',
    };
    final space = switch ('${row['requested_space_type']}') {
      'room' => 'غرفة خاصة',
      'table' => 'طاولة',
      _ => 'غرفة أو طاولة',
    };
    final canHandle = canManage &&
        const {'pending', 'quote_declined'}.contains(status);
    final colors = Theme.of(context).colorScheme;
    final occasionIcon = switch ('${row['occasion_type']}') {
      'birthday' => AppIcons.gift,
      'graduation' => AppIcons.userCheck01,
      'family_gathering' => AppIcons.userGroup,
      _ => AppIcons.sparkles,
    };
    final eventTime = DateTime.tryParse(
      '${row['quoted_start_at'] ?? row['preferred_start_at'] ?? ''}',
    )?.toLocal();
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetails(context, row),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: AppIcon(occasionIcon, color: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _RequestStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${row['customer_name'] ?? '—'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${row['branch_name_ar'] ?? row['branch_name_en'] ?? ''} · ${row['customer_phone'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (eventTime != null)
                _RequestDetailLine(
                  icon: AppIcons.calendar01,
                  text: _eventWindow(row, eventTime),
                ),
              _RequestDetailLine(
                icon: AppIcons.userMultiple,
                text: '${row['guest_count'] ?? '—'} ضيف · $space',
              ),
              if ('${row['estimated_budget'] ?? ''}'.trim().isNotEmpty)
                _RequestDetailLine(
                  icon: AppIcons.wallet01,
                  text: 'الميزانية: ${row['estimated_budget']} ${S.currency}',
                ),
              if ('${row['requested_services'] ?? ''}'.trim().isNotEmpty)
                _RequestDetailLine(
                  icon: AppIcons.sparkles,
                  text: 'الخدمات: ${row['requested_services']}',
                ),
              if ('${row['customer_note'] ?? ''}'.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    'ملاحظة العميل: ${row['customer_note']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Spacer(),
              if (status == 'quoted')
                Text(
                  'عرض ${row['quote_amount'] ?? ''} ${S.currency} · بانتظار رد العميل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (canHandle)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'حذف الطلب',
                        onPressed: () => _delete(context, '${row['id']}'),
                        icon: const AppIcon(AppIcons.delete01),
                        color: colors.error,
                      ),
                    TextButton(
                      onPressed: () => _reject(context, '${row['id']}'),
                      child: const Text('رفض الطلب'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _quote(context, row),
                      icon: const AppIcon(AppIcons.money01),
                      label: const Text('إرسال عرض'),
                    ),
                  ],
                ),
              if (!canHandle && canManage && onDelete != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: 'حذف الطلب',
                    onPressed: () => _delete(context, '${row['id']}'),
                    icon: const AppIcon(AppIcons.delete01),
                    color: colors.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context, Map<String, dynamic> row) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('تفاصيل ${row['occasion_name'] ?? 'المناسبة'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in <(String, String)>[
                    ('الحالة', '${row['status'] ?? ''}'),
                    ('العميل', '${row['customer_name'] ?? ''}'),
                    ('رقم الهاتف', '${row['customer_phone'] ?? ''}'),
                    (
                      'المناسبة',
                      '${row['occasion_name'] ?? row['occasion_type'] ?? ''}',
                    ),
                    ('الفرع', '${row['branch_name_ar'] ?? row['branch_name_en'] ?? ''}'),
                    (
                      'موعد العميل المقترح',
                      '${row['preferred_start_at'] ?? ''} - ${row['preferred_end_at'] ?? ''}',
                    ),
                    ('عدد الضيوف', '${row['guest_count'] ?? ''}'),
                    ('المكان المطلوب', '${row['requested_space_type'] ?? ''}'),
                    ('الخدمات', '${row['requested_services'] ?? '—'}'),
                    ('الميزانية', '${row['estimated_budget'] ?? '—'}'),
                    ('ملاحظات العميل', '${row['customer_note'] ?? '—'}'),
                    ('المكان المعروض', '${row['quoted_space_name'] ?? '—'}'),
                    (
                      'الموعد المعروض',
                      '${row['quoted_start_at'] ?? '—'} - ${row['quoted_end_at'] ?? ''}',
                    ),
                    ('قيمة العرض', '${row['quote_amount'] ?? '—'} ${S.currency}'),
                    ('ملاحظة العرض', '${row['quote_note'] ?? '—'}'),
                    ('التذكير', '${row['reminder_at'] ?? '—'}'),
                    ('تاريخ تقديم الطلب', '${row['created_at'] ?? ''}'),
                  ]) ...[
                    Text(field.$1, style: Theme.of(ctx).textTheme.labelMedium),
                    Text(field.$2),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.close),
            ),
          ],
        ),
      );

  Future<void> _reject(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض طلب المناسبة؟'),
        content: const Text('سيظهر للعميل أن الفرع لم يتمكن من قبول الطلب.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onReject(id);
  }

  Future<void> _delete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف طلب المناسبة؟'),
        content: const Text(
          'سيُحذف الطلب نهائيًا. إذا كان مرتبطًا بحجز مؤكد فسيبقى الحجز محفوظًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const AppIcon(AppIcons.delete01),
            label: const Text('حذف الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleteRequest = onDelete;
    if (deleteRequest == null) return;
    final deleted = await deleteRequest(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'تم حذف طلب المناسبة.' : 'تعذر حذف الطلب.'),
      ),
    );
  }

  Future<void> _quote(BuildContext context, Map<String, dynamic> row) async {
    final guestCount = int.tryParse('${row['guest_count']}') ?? 1;
    final type = '${row['requested_space_type'] ?? 'any'}';
    final available = tables
        .where(
          (t) =>
              t.isActive &&
              t.capacity >= guestCount &&
              (type == 'any' ||
                  (type == 'room') == (t.area == DiningArea.privateRoom)),
        )
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد غرفة أو طاولة نشطة تكفي عدد الضيوف لهذا الطلب.',
          ),
        ),
      );
      return;
    }
    final preferredStart =
        DateTime.tryParse('${row['preferred_start_at'] ?? ''}')?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    final preferredEnd =
        DateTime.tryParse('${row['preferred_end_at'] ?? ''}')?.toLocal() ??
        preferredStart.add(const Duration(hours: 2));
    final amount = TextEditingController();
    final note = TextEditingController();
    final chosenSpaces = available.map((table) => table.id).toSet();
    var day = DateTime(
      preferredStart.year,
      preferredStart.month,
      preferredStart.day,
    );
    var start = TimeOfDay.fromDateTime(preferredStart);
    var end = TimeOfDay.fromDateTime(preferredEnd);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إرسال عرض المناسبة'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 4),
                      child: Text('الأماكن المتاحة للعميل للاختيار منها'),
                    ),
                  ),
                  for (final table in available)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          if (table.imageUrl?.trim().isNotEmpty == true)
                            Image.network(
                              table.imageUrl!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          CheckboxListTile(
                            value: chosenSpaces.contains(table.id),
                            title: Text(table.name),
                            subtitle: Text('سعة ${table.capacity} ضيوف'),
                            onChanged: (checked) => setDialogState(() {
                              if (checked == true) {
                                chosenSpaces.add(table.id);
                              } else {
                                chosenSpaces.remove(table.id);
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'السعر الإجمالي (${S.currency})',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الموعد المقترح'),
                    subtitle: Text(
                      '${_format(day)} · ${start.format(context)} - ${end.format(context)}',
                    ),
                    onTap: () async {
                      final pickedDay = await showDatePicker(
                        context: ctx,
                        initialDate: day.isBefore(DateTime.now())
                            ? DateTime.now()
                            : day,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDay == null || !ctx.mounted) return;
                      final pickedStart = await showTimePicker(
                        context: ctx,
                        initialTime: start,
                      );
                      if (pickedStart == null || !ctx.mounted) return;
                      final pickedEnd = await showTimePicker(
                        context: ctx,
                        initialTime: end,
                      );
                      if (pickedEnd != null) {
                        setDialogState(() {
                          day = pickedDay;
                          start = pickedStart;
                          end = pickedEnd;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل العرض (اختياري)',
                    ),
                  ),
                  const Text(
                    'صلاحية العرض 48 ساعة. يتأكد الحجز بعد موافقة العميل.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال العرض'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      amount.dispose();
      note.dispose();
      return;
    }
    if (result == true) {
      final value = double.tryParse(amount.text.trim());
      final startAt = DateTime(
        day.year,
        day.month,
        day.day,
        start.hour,
        start.minute,
      );
      var endAt = DateTime(day.year, day.month, day.day, end.hour, end.minute);
      if (!endAt.isAfter(startAt)) endAt = endAt.add(const Duration(days: 1));
      if (value == null ||
          value < 0 ||
          !startAt.isAfter(DateTime.now()) ||
          endAt.difference(startAt).inMinutes < 30 ||
          endAt.difference(startAt).inMinutes > 480) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تحقق من السعر والموعد؛ المدة يجب أن تكون بين 30 دقيقة و8 ساعات.',
            ),
          ),
        );
      } else {
        if (chosenSpaces.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اختر مكانًا واحدًا على الأقل للعميل.')),
          );
          amount.dispose();
          note.dispose();
          return;
        }
        final ok = await onOffer(
          id: '${row['id']}',
          amount: value,
          spaceIds: chosenSpaces.toList(growable: false),
          startAt: startAt,
          endAt: endAt,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? 'تم إرسال العرض للعميل.'
                    : 'تعذر إرسال العرض. تحقق من الصلاحيات وتوفر المكان.',
              ),
            ),
          );
        }
      }
    }
    amount.dispose();
    note.dispose();
  }

  String _format(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _eventWindow(Map<String, dynamic> row, DateTime start) {
    final end = DateTime.tryParse(
      '${row['quoted_end_at'] ?? row['preferred_end_at'] ?? ''}',
    )?.toLocal();
    return end == null ? _format(start) : '${_format(start)} - ${_time(end)}';
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (status) {
      'pending' => 'جديد',
      'quoted' => 'عرض مرسل',
      'quote_declined' => 'مرفوض',
      'rejected' => 'مرفوض',
      'confirmed' => 'مؤكد',
      'cancelled' => 'ملغي',
      _ => status,
    };
    final color = status == 'confirmed'
        ? colors.tertiary
        : status == 'quote_declined'
        ? colors.error
        : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RequestDetailLine extends StatelessWidget {
  const _RequestDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        AppIcon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
