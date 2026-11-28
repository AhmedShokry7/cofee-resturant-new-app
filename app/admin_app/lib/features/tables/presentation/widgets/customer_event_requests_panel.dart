import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
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
        const gap = 14.0;
        const minCardWidth = 240.0;
        // عدد الكروت في الصف يتبع العرض المتاح حتى 5 كروت جنب بعض.
        final columns = ((constraints.maxWidth + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, 5)
            .toInt();
        // كل صف بارتفاع أطول كارد فيه، فالكارد يأخذ ارتفاع محتواه فقط،
        // والكروت في الصف الواحد متساوية الارتفاع.
        final rows = <Widget>[
          for (var start = 0; start < active.length; start += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                        child: start + i < active.length
                            ? _requestCard(context, active[start + i])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ];
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        );
      },
    );
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final type = _occasionLabel(row);
    final space = _spaceLabel('${row['requested_space_type']}');
    final canHandle = canManage &&
        const {'pending', 'quote_declined'}.contains(status);
    final colors = Theme.of(context).colorScheme;
    final occasionIcon = _occasionIcon('${row['occasion_type']}');
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
                      color: colors.primary.withValues(alpha: .12),
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
              const SizedBox(height: 12),
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
              const Spacer(),
              if (canHandle)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
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
              if (canManage && onDelete != null)
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
        builder: (ctx) => _EventRequestDetailsDialog(row: row),
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

String _occasionLabel(Map<String, dynamic> row) =>
    switch ('${row['occasion_type']}') {
      'birthday' => 'عيد ميلاد',
      'graduation' => 'حفل تخرج',
      'family_gathering' => 'تجمع عائلي',
      _ => '${row['occasion_name'] ?? ''}'.trim().isEmpty
          ? 'مناسبة خاصة'
          : '${row['occasion_name']}',
    };

IconData _occasionIcon(String occasionType) => switch (occasionType) {
      'birthday' => AppIcons.gift,
      'graduation' => AppIcons.userCheck01,
      'family_gathering' => AppIcons.userGroup,
      _ => AppIcons.sparkles,
    };

String _spaceLabel(String spaceType) => switch (spaceType) {
      'room' => 'غرفة خاصة',
      'table' => 'طاولة',
      _ => 'غرفة أو طاولة',
    };

List<Map<String, dynamic>> _spaceOptions(Map<String, dynamic> row) {
  final raw = row['quoted_space_options'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String? _text(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

DateTime? _parseDateTime(Object? value) =>
    DateTime.tryParse('${value ?? ''}')?.toLocal();

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatDate(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')} · ${_formatTime(value)}';

class _EventRequestDetailsDialog extends StatelessWidget {
  const _EventRequestDetailsDialog({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = '${row['status'] ?? ''}';
    final options = _spaceOptions(row);
    final selectedId = '${row['quoted_space_id'] ?? ''}';
    final selectedIndex = options.indexWhere(
      (option) => '${option['id']}' == selectedId,
    );
    final selected = options.isEmpty
        ? const <String, dynamic>{}
        : options[selectedIndex < 0 ? 0 : selectedIndex];
    final offered = row['quoted_start_at'] != null;
    final start = _parseDateTime(
      row['quoted_start_at'] ?? row['preferred_start_at'],
    );
    final end = _parseDateTime(row['quoted_end_at'] ?? row['preferred_end_at']);
    final expires = _parseDateTime(row['quote_expires_at']);
    final created = _parseDateTime(row['created_at']);
    final quoteAmount = row['quote_amount'];
    final budget = row['estimated_budget'];
    final branch =
        _text(row['branch_name_ar']) ?? _text(row['branch_name_en']) ?? '—';
    final customerName = _text(row['customer_name']) ?? '—';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppIcon(
                      _occasionIcon('${row['occasion_type']}'),
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _occasionLabel(row),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$customerName · $branch',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RequestStatusBadge(status: status),
                  IconButton(
                    tooltip: S.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const AppIcon(AppIcons.cancel01),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hero(
                      context,
                      imageUrl: '${selected['image_url'] ?? ''}'.trim(),
                      name: _text(selected['name']) ??
                          _text(row['quoted_space_name']) ??
                          '',
                      capacity: selected['capacity'],
                      emptyLabel: offered
                          ? 'لا توجد صورة لهذا المكان'
                          : 'لم يُرسل عرض بعد',
                    ),
                    if (options.length > 1) ...[
                      const SizedBox(height: 22),
                      _sectionTitle(
                        context,
                        'الأماكن المعروضة على العميل (${options.length})',
                      ),
                      const SizedBox(height: 10),
                      _optionsStrip(context, options, selectedId),
                    ],
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'موعد المناسبة'),
                    const SizedBox(height: 10),
                    _infoGrid([
                      _InfoTile(
                        icon: AppIcons.calendar01,
                        label: offered ? 'الموعد المعروض' : 'الموعد المطلوب',
                        value: start == null
                            ? '—'
                            : end == null
                                ? _formatDate(start)
                                : '${_formatDate(start)} - ${_formatTime(end)}',
                      ),
                      _InfoTile(
                        icon: AppIcons.userMultiple,
                        label: 'عدد الضيوف',
                        value: '${row['guest_count'] ?? '—'}',
                      ),
                      _InfoTile(
                        icon: AppIcons.sofa01,
                        label: 'نوع المكان المطلوب',
                        value: _spaceLabel('${row['requested_space_type']}'),
                      ),
                      _InfoTile(
                        icon: AppIcons.wallet01,
                        label: 'الميزانية',
                        value: budget == null ? '—' : '$budget ${S.currency}',
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'بيانات العميل'),
                    const SizedBox(height: 10),
                    _infoGrid([
                      _InfoTile(
                        icon: AppIcons.user,
                        label: 'اسم العميل',
                        value: customerName,
                      ),
                      _InfoTile(
                        icon: AppIcons.call02,
                        label: 'رقم الهاتف',
                        value: _text(row['customer_phone']) ?? '—',
                      ),
                      _InfoTile(
                        icon: AppIcons.store01,
                        label: 'الفرع',
                        value: branch,
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'العرض'),
                    const SizedBox(height: 10),
                    _infoGrid([
                      _InfoTile(
                        icon: AppIcons.money01,
                        label: 'قيمة العرض',
                        value: quoteAmount == null
                            ? 'لم يُرسل عرض بعد'
                            : '$quoteAmount ${S.currency}',
                      ),
                      _InfoTile(
                        icon: AppIcons.timer01,
                        label: 'صلاحية العرض',
                        value: expires == null ? '—' : _formatDate(expires),
                      ),
                    ]),
                    for (final note in <(IconData, String, Object?)>[
                      (AppIcons.sparkles, 'الخدمات المطلوبة', row['requested_services']),
                      (AppIcons.note01, 'ملاحظة العميل', row['customer_note']),
                      (AppIcons.note, 'ملاحظة العرض', row['quote_note']),
                    ])
                      if (_text(note.$3) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _InfoTile(
                            icon: note.$1,
                            label: note.$2,
                            value: _text(note.$3)!,
                          ),
                        ),
                    if (created != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          'تاريخ تقديم الطلب: ${_formatDate(created)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _infoGrid(List<Widget> tiles) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= 480;
      final width = twoColumns
          ? (constraints.maxWidth - 10) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final tile in tiles) SizedBox(width: width, child: tile),
        ],
      );
    },
  );

  Widget _hero(
    BuildContext context, {
    required String imageUrl,
    required String name,
    required Object? capacity,
    required String emptyLabel,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.image01, size: 40, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isEmpty
                ? placeholder
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
            if (name.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColor.transparent,
                        AppColor.blackColor.withValues(alpha: .75),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 36, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColor.whiteColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (capacity != null)
                          Text(
                            'سعة $capacity ضيوف',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColor.whiteColor.withValues(alpha: .85),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionsStrip(
    BuildContext context,
    List<Map<String, dynamic>> options,
    String selectedId,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = '${option['id']}' == selectedId;
          final imageUrl = '${option['image_url'] ?? ''}'.trim();
          return Container(
            width: 160,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? colors.primary : colors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 70,
                  width: double.infinity,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Center(
                            child: AppIcon(
                              AppIcons.image01,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${option['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_spaceLabel('${option['space_type']}')} · سعة ${option['capacity'] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppIcon(icon, color: colors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
