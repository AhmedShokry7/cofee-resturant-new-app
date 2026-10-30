import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_stamp_field.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// ما يرسله المدير من طلب تصحيح بصمة.
///
/// الطابع الذي لم يُمَسّ يبقى `null`: القاعدة تقرأ غيابه «لا تغيير هنا» وتترك
/// البصمة كما هي، أما الوقت المخترع فيُكتب في السجلّ شاهدًا لم يطلبه أحد.
class HrCorrectionDraft {
  const HrCorrectionDraft({
    required this.staffId,
    required this.reason,
    this.sessionId,
    this.clockInAt,
    this.clockOutAt,
  });

  final String staffId;
  final String reason;

  /// `null` حين يسجّل الطلب جلسة جديدة، ومعرّف الجلسة حين يعدّل قائمة.
  final String? sessionId;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
}

/// حوار فتح اعتراض على بصمة: موظف، وطابع مقترح، وسبب.
///
/// الجلسة لا تُحرَّر محليًا أبدًا — هذا طلب عند صاحبي القرار، والحوار لا يدّعي
/// تعديلًا لم يحدث: لا يقبل إرسالًا بلا بصمة ممسوسة واحدة ولا بلا سبب. أما
/// الفرع فلا يُسأل هنا: `hr.open_session_for_staff` يختاره من ارتباط الموظف
/// النشط وحدها، فسؤاله في الواجهة يوحي بيدٍ للشاشة في قرار ليس لها.
Future<HrCorrectionDraft?> showHrCorrectionRequestDialog(
  BuildContext context, {
  required List<HrPersonOption>? people,
  HrAttendanceRow? row,
}) => showDialog<HrCorrectionDraft>(
  context: context,
  builder: (dialogContext) => _HrCorrectionDialog(people: people, row: row),
);

class _HrCorrectionDialog extends StatefulWidget {
  const _HrCorrectionDialog({required this.people, this.row});

  final List<HrPersonOption>? people;
  final HrAttendanceRow? row;

  @override
  State<_HrCorrectionDialog> createState() => _HrCorrectionDialogState();
}

class _HrCorrectionDialogState extends State<_HrCorrectionDialog> {
  final TextEditingController _reason = TextEditingController();
  String? _staffId;
  DateTime? _clockInAt;
  DateTime? _clockOutAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    // من جدول الحضور يأتي الموظف مع جلسته، ومن الرأس يبدأ طلبًا حرًا.
    _staffId = widget.row?.staffId ?? hrFirstPersonId(widget.people);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _setClockIn(DateTime value) => setState(() => _clockInAt = value);

  void _setClockOut(DateTime value) => setState(() => _clockOutAt = value);

  void _submit() {
    final staff = _staffId;
    if (staff == null) {
      setState(() => _error = S.hrStaffMissing);
      return;
    }
    // بصمة لم تُمَسَّ ليست تغييرًا: الطلب بلا تغيير يرفضه السطر نفسه.
    if (_clockInAt == null && _clockOutAt == null) {
      setState(() => _error = S.hrNoChangeProposed);
      return;
    }
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = S.hrReasonMissing);
      return;
    }
    final sessionId = widget.row?.id;
    Navigator.of(context).pop(
      HrCorrectionDraft(
        staffId: staff,
        reason: reason,
        sessionId: sessionId == null || sessionId.isEmpty ? null : sessionId,
        clockInAt: _clockInAt,
        clockOutAt: _clockOutAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return HrFormDialog(
      title: S.hrCorrectionTitle,
      error: _error,
      subtitle: row == null ? null : hrPersonName(row.staffName),
      saveLabel: S.hrBtnRequestCorrection,
      saveKey: const Key('hr-correction-save'),
      onSave: _submit,
      children: [
        hrEmployeeField(
          context,
          people: widget.people,
          value: _staffId,
          onChanged: (value) => setState(() => _staffId = value),
        ),
        if (row != null) ...[
          const SizedBox(height: AppSpacing.md),
          HrCellText(S.hrCorrectionCurrent, muted: true),
          const SizedBox(height: AppSpacing.xxs),
          HrCellText(
            '${_stamp(row.clockInLocal)} → ${_stamp(row.clockOutLocal)}',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        HrStampField(
          label: S.hrCorrectionClockIn,
          value: _clockInAt,
          onChanged: _setClockIn,
        ),
        const SizedBox(height: AppSpacing.md),
        HrStampField(
          label: S.hrCorrectionClockOut,
          value: _clockOutAt,
          onChanged: _setClockOut,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _reason,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrReasonLabel,
            hint: S.hrReasonHint,
            required: true,
          ),
        ),
      ],
    );
  }

  /// بصمة مسجّلة بلا قيمة تُلفظ «لم تُختَر»: الخلية الفارغة تُقرأ نسيانًا.
  String _stamp(String value) => value.isEmpty ? S.hrNotSelected : value;
}
