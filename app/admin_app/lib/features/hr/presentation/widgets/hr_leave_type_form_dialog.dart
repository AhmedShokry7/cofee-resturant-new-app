import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// ما يرسل الحوار لنوع الإجازة، بنفس ترتيب وسمة `saveLeaveType`.
///
/// `id` يبقى `null` للنوع الجديد: الكتابة في القاعدة تقرر هل هذا إدراج أم
/// تحديث، والشاشة لا تخترع معرّفًا لم تقرأه.
class HrLeaveTypeDraft {
  const HrLeaveTypeDraft({
    this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.requiresDocument,
    required this.isPaid,
    required this.tracksBalance,
    this.defaultAnnualDays,
    required this.isActive,
  });

  final String? id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool requiresDocument;
  final bool isPaid;
  final bool tracksBalance;

  /// أيام السنة: `null` تعني أن الحقل تُرك فراغًا فلا تُكتب قاعدة استحقاق.
  final double? defaultAnnualDays;
  final bool isActive;
}

/// حوار نوع إجازة: رمزه ولغتاه وأربع رءوس قراره.
///
/// الرمز الحروف الصغيرة والشرطة السفلى لأن 212 ترفض شكلًا غيره، والاسمان
/// مطلوبان معًا لأن القائمة تُعرض بلغتين؛ والحوار يعدّل نوعًا قرئ، لا يختار
/// حالة لم يخترها أحد.
Future<HrLeaveTypeDraft?> showHrLeaveTypeFormDialog(
  BuildContext context, {
  HrLeaveType? existing,
}) => showDialog<HrLeaveTypeDraft>(
  context: context,
  builder: (dialogContext) => _HrLeaveTypeForm(existing: existing),
);

class _HrLeaveTypeForm extends StatefulWidget {
  const _HrLeaveTypeForm({this.existing});

  final HrLeaveType? existing;

  @override
  State<_HrLeaveTypeForm> createState() => _HrLeaveTypeFormState();
}

class _HrLeaveTypeFormState extends State<_HrLeaveTypeForm> {
  /// شكل الرمز كما تقيّده القاعدة: حروفًا صغيرة ومسافات سفلى فقط.
  static final RegExp _codeShape = RegExp(r'^[a-z_]+$');

  final TextEditingController _code = TextEditingController();
  final TextEditingController _nameAr = TextEditingController();
  final TextEditingController _nameEn = TextEditingController();
  final TextEditingController _days = TextEditingController();
  bool _requiresDocument = false;
  bool _isPaid = true;
  bool _tracksBalance = false;
  bool _isActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final type = widget.existing;
    if (type == null) return;
    _code.text = type.code;
    _nameAr.text = type.nameAr;
    _nameEn.text = type.nameEn;
    _requiresDocument = type.requiresDocument;
    _isPaid = type.isPaid;
    _tracksBalance = type.tracksBalance;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _code,
      _nameAr,
      _nameEn,
      _days,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim();
    if (!_codeShape.hasMatch(code)) {
      setState(() => _error = S.hrLeaveTypeCodeShape);
      return;
    }
    if (_nameAr.text.trim().isEmpty || _nameEn.text.trim().isEmpty) {
      setState(() => _error = S.hrBothNamesRequired);
      return;
    }
    final days = normalizeDigits(_days.text.trim());
    if (days.isNotEmpty) {
      final value = double.tryParse(days);
      if (value == null) {
        setState(() => _error = S.hrNumberMissing);
        return;
      }
      if (value < 0) {
        setState(() => _error = S.hrNegativeEntitlement);
        return;
      }
    }
    Navigator.of(context).pop(
      HrLeaveTypeDraft(
        id: widget.existing?.id,
        code: code,
        nameAr: _nameAr.text.trim(),
        nameEn: _nameEn.text.trim(),
        requiresDocument: _requiresDocument,
        isPaid: _isPaid,
        tracksBalance: _tracksBalance,
        defaultAnnualDays: days.isEmpty ? null : double.parse(days),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HrFormDialog(
      title: S.hrBtnNewLeaveType,
      error: _error,
      subtitle: widget.existing?.code,
      saveLabel: S.save,
      saveKey: const Key('hr-leave-type-save'),
      onSave: _submit,
      children: [
        _text(_code, S.hrLeaveTypeCode, required: true),
        _gap(_text(_nameAr, S.hrLeaveTypeNameAr, required: true)),
        _gap(_text(_nameEn, S.hrLeaveTypeNameEn, required: true)),
        _gap(_text(_days, S.hrLeaveTypeDays, numeric: true)),
        _gap(
          _switch(
            S.hrLeaveTypePaid,
            _isPaid,
            (v) => setState(() => _isPaid = v),
          ),
        ),
        _gap(
          _switch(
            S.hrLeaveTypeTracks,
            _tracksBalance,
            (v) => setState(() => _tracksBalance = v),
          ),
        ),
        _gap(
          _switch(
            S.hrLeaveTypeRequiresDoc,
            _requiresDocument,
            (v) => setState(() => _requiresDocument = v),
          ),
        ),
        _gap(
          _switch(
            S.hrLeaveTypeActive,
            _isActive,
            (v) => setState(() => _isActive = v),
          ),
        ),
      ],
    );
  }

  /// حقل الحوار: الرمز والاسمان حروف، وأيام السنة رقم وحدها.
  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
  }) => TextField(
    controller: controller,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    style: const TextStyle(fontSize: AppFontSizes.size12_5),
    decoration: adminDialogFieldDecoration(context, label: label, hint: ''),
  );

  /// مفتاح قرار: لفظه أمامه، فالحالة تُقرأ ولا تُستنتج من موضع المفتاح.
  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => Row(
    children: [
      Expanded(child: Text(label)),
      Switch(value: value, onChanged: onChanged),
    ],
  );

  Widget _gap(Widget child) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: child,
  );
}
