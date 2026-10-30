import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_amount_field.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// ما يرسله الموظف لطلب سلفة: مبلغ، وقسط اختياري، وسبب لا يُرفض فراغه.
class HrAdvanceDraft {
  const HrAdvanceDraft({
    required this.amount,
    required this.reason,
    this.installment,
  });

  final double amount;
  final String reason;
  final double? installment;
}

/// حوار طلب سلفة على الراتب.
///
/// السلفة لا تُصرَف من هنا: الطلب يُختم `pending` وينتظر قرار الإدارة في شاشة
/// السلف، فالزرّ هنا «طلب» لا «صرف» ولا يوعد بمال لم يعتمده أحد.
Future<HrAdvanceDraft?> showHrAdvanceDialog(BuildContext context) =>
    showDialog<HrAdvanceDraft>(
      context: context,
      builder: (dialogContext) => const _HrAdvanceDialog(),
    );

class _HrAdvanceDialog extends StatefulWidget {
  const _HrAdvanceDialog();

  @override
  State<_HrAdvanceDialog> createState() => _HrAdvanceDialogState();
}

class _HrAdvanceDialogState extends State<_HrAdvanceDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _installment = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _installment.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final reason = _reason.text.trim();
    if (amount <= 0) {
      setState(() => _error = S.hrAmountMustBePositive);
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = S.hrReasonMissing);
      return;
    }
    final installment = double.tryParse(_installment.text.trim());
    Navigator.of(context).pop(
      HrAdvanceDraft(
        amount: amount,
        reason: reason,
        installment: installment == null || installment <= 0
            ? null
            : installment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDialogHeader(
              title: S.hrBtnRequestAdvance,
              subtitle: S.hrAdvanceRequestHint,
              onClose: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HrAmountField(
                    label: S.amount,
                    hint: S.hrAmountHint,
                    controller: _amount,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HrAmountField(
                    label: S.hrInstallmentOptional,
                    hint: S.hrAmountHint,
                    controller: _installment,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontSize: AppFontSizes.size12_5),
                    decoration: adminDialogFieldDecoration(
                      context,
                      label: S.hrReasonLabel,
                      hint: S.hrReasonHint,
                      required: true,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: AdminErrorBanner(message: _error!),
                    ),
                ],
              ),
            ),
            AdminDialogFooter(
              saving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _submit,
              saveKey: const Key('hr-advance-save'),
              saveLabel: S.hrBtnRequestAdvance,
              savingLabel: S.hrBtnRequestAdvance,
            ),
          ],
        ),
      ),
    );
  }
}
