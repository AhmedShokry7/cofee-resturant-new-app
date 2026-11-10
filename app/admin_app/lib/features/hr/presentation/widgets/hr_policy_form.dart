import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_amount_field.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// سياسة العمل كما يقرؤها المدير: الحقول السبعة في `hr.settings` بلا سواها.
///
/// تُرسل القيمة التي كُتبت وحدها؛ والفراغ في سعر دقيقة يبقى `null` لأن 212
/// تترك المخزن عندها، أما صفر مختَرع فيُعيد سياسة الموظف إلى لا شيء.
/// ومن لا يملك `hr.settings.manage` يرفض سطره لا إخفاؤه، فلا تعرف الشاشة
/// الصلاحيات: هي تعرض ما قرأت وتكتب ما طُلب منها.
class HrPolicyForm extends StatefulWidget {
  const HrPolicyForm({
    super.key,
    required this.value,
    required this.busy,
    required this.onSave,
  });

  /// السياسة المقروءة الآن: منها تبدأ الحقول، وإليها ترجع بعد كل حفظ.
  final HrSettings value;
  final bool busy;
  final ValueChanged<HrPolicyDraft> onSave;

  @override
  State<HrPolicyForm> createState() => _HrPolicyFormState();
}

/// القيم السبعة التي يرسل الحفظ، بنفس ترتيب `HrSettingsCubit.updateSettings`.
class HrPolicyDraft {
  const HrPolicyDraft({
    required this.businessTimeZone,
    required this.lateGraceMinutes,
    this.lateMinuteRate,
    this.earlyMinuteRate,
    this.absenceDayRate,
    required this.cashierDeductionAllowed,
    required this.maxSalaryDeductionPercent,
  });

  final String businessTimeZone;
  final int lateGraceMinutes;

  /// سعر لم يُكتب: يُرسل `null` فيبقى المخزن في القاعدة كما هو.
  final double? lateMinuteRate;
  final double? earlyMinuteRate;
  final double? absenceDayRate;
  final bool cashierDeductionAllowed;
  final double maxSalaryDeductionPercent;
}

class _HrPolicyFormState extends State<HrPolicyForm> {
  final TextEditingController _timeZone = TextEditingController();
  final TextEditingController _grace = TextEditingController();
  final TextEditingController _late = TextEditingController();
  final TextEditingController _early = TextEditingController();
  final TextEditingController _absence = TextEditingController();
  final TextEditingController _cap = TextEditingController();
  bool _cashier = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seed(widget.value);
  }

  @override
  void didUpdateWidget(HrPolicyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // بعد الحفظ يرد المرجع بسياسة جديدة، فالحقول تتبع ما قرئ لا ما كُتب يدويًا.
    if (oldWidget.value != widget.value) _seed(widget.value);
  }

  void _seed(HrSettings settings) {
    _timeZone.text = settings.businessTimeZone;
    // الأرقام تُكتب في الحقل بحروفها الغربية لأن ما يُقرأ منها يُرسل للقاعدة.
    _grace.text = '${settings.lateGraceMinutes}';
    _late.text = _amount(settings.lateMinuteRate);
    _early.text = _amount(settings.earlyMinuteRate);
    _absence.text = _amount(settings.absenceDayRate);
    _cap.text = '${settings.maxSalaryDeductionPercent}';
    _cashier = settings.cashierDeductionAllowed;
    _error = null;
  }

  String _amount(double? value) => value == null ? '' : '$value';

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _timeZone,
      _grace,
      _late,
      _early,
      _absence,
      _cap,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// التحقق المحلي قبل الإرسال: المدى تعرفه القاعدة، والحقل يعرف رقمه فقط.
  void _submit() {
    final grace = int.tryParse(normalizeDigits(_grace.text.trim()));
    final cap = double.tryParse(normalizeDigits(_cap.text.trim()));
    if (grace == null || cap == null) {
      setState(() => _error = S.hrNumberMissing);
      return;
    }
    setState(() => _error = null);
    widget.onSave(
      HrPolicyDraft(
        businessTimeZone: _timeZone.text.trim(),
        lateGraceMinutes: grace,
        lateMinuteRate: _parse(_late),
        earlyMinuteRate: _parse(_early),
        absenceDayRate: _parse(_absence),
        cashierDeductionAllowed: _cashier,
        maxSalaryDeductionPercent: cap,
      ),
    );
  }

  double? _parse(TextEditingController controller) {
    final text = normalizeDigits(controller.text.trim());
    return text.isEmpty ? null : double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminSectionCard(
      title: S.hrPolicyTitle,
      subtitle: S.hrPolicySubtitle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth < 720
              ? constraints.maxWidth
              : (constraints.maxWidth - AppSpacing.sm) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _textField(_timeZone, S.hrPolicyTimezone),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _textField(
                      _grace,
                      S.hrPolicyLateGrace,
                      numeric: true,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: HrAmountField(
                      label: S.hrPolicyLateRate,
                      hint: S.hrAmountHint,
                      controller: _late,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: HrAmountField(
                      label: S.hrPolicyEarlyRate,
                      hint: S.hrAmountHint,
                      controller: _early,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: HrAmountField(
                      label: S.hrPolicyAbsenceRate,
                      hint: S.hrAmountHint,
                      controller: _absence,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _textField(
                      _cap,
                      S.hrPolicyDeductionCap,
                      numeric: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text(S.hrPolicyCashierSwitch)),
                  Switch(
                    value: _cashier,
                    onChanged: widget.busy
                        ? null
                        : (value) => setState(() => _cashier = value),
                  ),
                ],
              ),
              _note(theme, S.hrPolicyCashierHint),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AdminErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.md),
              CustomBtn(
                text: S.hrBtnSavePolicy,
                enabled: !widget.busy,
                isLoading: widget.busy,
                loadingText: S.saving,
                onPressed: _submit,
              ),
            ],
          );
        },
      ),
    );
  }

  /// حقل نص أو رقم: المنطقة الزمنية تُكتب حروفًا، والدقائق والسقف أرقام.
  Widget _textField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) => TextField(
    controller: controller,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    style: const TextStyle(fontSize: AppFontSizes.size12_5),
    decoration: adminDialogFieldDecoration(context, label: label, hint: ''),
  );

  Widget _note(ThemeData theme, String message) => Text(
    message,
    style: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10_5,
      height: AppTextHeights.line1_5,
    ),
  );
}
