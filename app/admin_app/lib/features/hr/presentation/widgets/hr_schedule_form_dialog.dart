import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_stamp_field.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// ما يرسله حوار جدول العمل: موظف، وفرع، ونافذة، واستراحة، وحالة.
///
/// `id` فارغ في الجديد وكامل في التعديل، لأن `hr.save_schedule` تفرّق بينهما
/// بالمعرّف وحده؛ والراحة بالدقائق كما تقرأها القاعدة، لا بالساعات المخمّنة.
class HrScheduleDraft {
  const HrScheduleDraft({
    required this.staffId,
    required this.branchId,
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.status,
    this.note,
    this.id,
  });

  final String staffId;
  final String branchId;
  final DateTime start;
  final DateTime end;
  final int breakMinutes;

  /// `draft|published` وحدهما: الإلغاء لا يمرّ من هذه الدالة.
  final String status;
  final String? note;
  final String? id;
}

/// حوار إنشاء وردية أو تعديلها، بقيمة مسبقة من الجدول حين كان تعديلًا.
///
/// `people` مرشَّحو الدليل كما قرأهم المرجع: `null` أنهم لم يُقرؤوا، و`[]` أنهم
/// قُرئوا ولا ملفّ في النطاق — ولا يُفتح حقلٌ أجوّف في الحالتين.
Future<HrScheduleDraft?> showHrScheduleFormDialog(
  BuildContext context, {
  required List<HrPersonOption>? people,
  required List<HrBranch> branches,
  HrWorkSchedule? existing,
}) => showDialog<HrScheduleDraft>(
  context: context,
  builder: (dialogContext) => _HrScheduleFormDialog(
    people: people,
    branches: branches,
    existing: existing,
  ),
);

class _HrScheduleFormDialog extends StatefulWidget {
  const _HrScheduleFormDialog({
    required this.people,
    required this.branches,
    this.existing,
  });

  final List<HrPersonOption>? people;
  final List<HrBranch> branches;
  final HrWorkSchedule? existing;

  @override
  State<_HrScheduleFormDialog> createState() => _HrScheduleFormDialogState();
}

class _HrScheduleFormDialogState extends State<_HrScheduleFormDialog> {
  static const List<String> _statuses = <String>['draft', 'published'];
  final TextEditingController _break = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _staffId;
  String? _branchId;
  String _status = _statuses.first;
  DateTime? _day;
  DateTime? _start;
  DateTime? _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final people = widget.people;
    _staffId =
        existing?.staffId ??
        (people == null || people.isEmpty ? null : people.first.id);
    _branchId =
        existing?.branchId ??
        (widget.branches.isEmpty ? null : widget.branches.first.id);
    final status = existing?.status;
    _status = status != null && _statuses.contains(status)
        ? status
        : _statuses.first;
    final start = existing?.scheduledStart?.toLocal();
    final end = existing?.scheduledEnd?.toLocal();
    _start = start;
    _day = start;
    // A shift belongs to one local workday. Rebuild the loaded end stamp on
    // that day while keeping its local clock time; old rows may carry a UTC
    // date boundary that differs from the business-local date.
    _end = _retime(end, start);
    _break.text = '${existing?.breakMinutes ?? 0}';
  }

  @override
  void dispose() {
    _break.dispose();
    _note.dispose();
    super.dispose();
  }

  /// يوم واحد للوردية: تغيير اليوم ينقل طابعيه معه، وتغيير الطابع يتّبع يومه.
  void _setDay(DateTime day) => setState(() {
    _day = day;
    _start = _retime(_start, day);
    _end = _retime(_end, day);
  });

  void _setStart(DateTime value) => setState(() {
    _start = value;
    _day = value;
    _end = _retime(_end, value);
  });

  DateTime? _retime(DateTime? stamp, DateTime? day) =>
      stamp == null || day == null
      ? stamp
      : DateTime(
          day.year,
          day.month,
          day.day,
          stamp.toLocal().hour,
          stamp.toLocal().minute,
        );

  void _submit() {
    final staff = _staffId;
    final branch = _branchId;
    final start = _start;
    final end = _end;
    if (staff == null) {
      setState(() => _error = S.hrStaffMissing);
      return;
    }
    if (branch == null) {
      setState(() => _error = S.hrPickBranchFirst);
      return;
    }
    if (start == null || end == null) {
      setState(() => _error = S.hrTimeMissing);
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => _error = S.hrInvalidScheduleWindow);
      return;
    }
    final minutes = _breakMinutes();
    if (minutes == null) {
      setState(() => _error = S.hrInvalidBreakLength);
      return;
    }
    final note = _noteText();
    Navigator.of(context).pop(
      HrScheduleDraft(
        staffId: staff,
        branchId: branch,
        start: start,
        end: end,
        breakMinutes: minutes,
        status: _status,
        note: note,
        id: widget.existing?.id,
      ),
    );
  }

  /// الاستراحة بالدقائق: الفراغ صفرًا حقيقيًا لا قيمة مخترعة، والسالب مرفوض.
  int? _breakMinutes() {
    final text = _break.text.trim();
    if (text.isEmpty) return 0;
    final parsed = int.tryParse(normalizeDigits(text));
    return parsed == null || parsed < 0 ? null : parsed;
  }

  String? _noteText() {
    final note = _note.text.trim();
    return note.isEmpty ? null : note;
  }

  @override
  Widget build(BuildContext context) {
    return HrFormDialog(
      title: S.hrScheduleTitle,
      subtitle: widget.existing?.branchName,
      saveLabel: S.save,
      error: _error,
      saveKey: const Key('hr-schedule-save'),
      onSave: _submit,
      children: [
        hrEmployeeField(
          context,
          people: widget.people,
          value: _staffId,
          onChanged: (value) => setState(() => _staffId = value),
        ),
        const SizedBox(height: AppSpacing.md),
        // فرع لم يُقرأ ليس قائمة فارغة: يُقال غيابه بدل أن يُعرض حقلًا أجوّف.
        if (widget.branches.isEmpty)
          HrCellText(S.hrNoBranchesForMe, muted: true)
        else
          hrDropdownField<String>(
            context,
            label: S.hrColBranch,
            value: _branchId,
            hint: S.hrPickBranchFirst,
            items: [
              for (final branch in widget.branches)
                DropdownMenuItem(
                  value: branch.id,
                  child: Text(
                    hrBranchName(branch),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _branchId = value),
          ),
        const SizedBox(height: AppSpacing.md),
        HrDateField(label: S.hrScheduleDate, value: _day, onChanged: _setDay),
        const SizedBox(height: AppSpacing.md),
        HrStampField(
          label: S.hrScheduleStartTime,
          value: _start,
          onChanged: _setStart,
        ),
        const SizedBox(height: AppSpacing.md),
        HrStampField(
          label: S.hrScheduleEndTime,
          value: _end,
          onChanged: (value) => setState(() => _end = value),
        ),
        const SizedBox(height: AppSpacing.md),
        // لا مثال بالدقائق في الألفاظ الموجودة، فيُترك الحقل بلا إشارة كاذبة.
        TextField(
          controller: _break,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrScheduleBreak,
            hint: '',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        hrDropdownField<String>(
          context,
          label: S.hrFilterStatus,
          value: _status,
          items: [
            for (final wire in _statuses)
              DropdownMenuItem(
                value: wire,
                child: Text(hrStatusLabel(wire).text),
              ),
          ],
          onChanged: (value) => setState(() => _status = value ?? _status),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 4,
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrFieldNote,
            hint: S.hrReasonHint,
          ),
        ),
      ],
    );
  }
}
