import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// ما يرسله الموظف من شاشة طلب الإجازة، بلا أي قرار عليه.
class HrLeaveDraft {
  const HrLeaveDraft({
    required this.leaveTypeId,
    required this.startsOn,
    required this.endsOn,
    this.reason,
    this.document,
  });

  final String leaveTypeId;
  final DateTime startsOn;
  final DateTime endsOn;
  final String? reason;
  final String? document;
}

/// حوار طلب إجازة: نوع، وتاريخان، وسبب، ومستند حين يطلبه النوع.
///
/// المستند لا يظهر إلا إذا كان `requires_document` في نوع الإجازة، لأن 212
/// ترفض الطلب الناقص وتشرح نقصه: الحقل المخفي يبيع المدير محاولة فاشلة.
Future<HrLeaveDraft?> showHrLeaveDialog(
  BuildContext context, {
  required List<HrLeaveType> types,
}) => showDialog<HrLeaveDraft>(
  context: context,
  builder: (dialogContext) => _HrLeaveDialog(types: types),
);

class _HrLeaveDialog extends StatefulWidget {
  const _HrLeaveDialog({required this.types});

  final List<HrLeaveType> types;

  @override
  State<_HrLeaveDialog> createState() => _HrLeaveDialogState();
}

class _HrLeaveDialogState extends State<_HrLeaveDialog> {
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _document = TextEditingController();
  String? _typeId;
  DateTime? _startsOn;
  DateTime? _endsOn;
  String? _error;

  HrLeaveType? get _type {
    for (final item in widget.types) {
      if (item.id == _typeId) return item;
    }
    return null;
  }

  void _submit() {
    final type = _type;
    final starts = _startsOn;
    final ends = _endsOn;
    if (type == null || starts == null || ends == null) {
      setState(() => _error = S.hrDatesMissing);
      return;
    }
    if (type.requiresDocument && _document.text.trim().isEmpty) {
      setState(() => _error = S.hrDocumentRequired);
      return;
    }
    Navigator.of(context).pop(
      HrLeaveDraft(
        leaveTypeId: type.id,
        startsOn: starts,
        endsOn: ends,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        document: _document.text.trim().isEmpty ? null : _document.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    _document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              title: S.hrBtnRequestLeave,
              onClose: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _typeId,
                    isExpanded: true,
                    decoration: adminDialogFieldDecoration(
                      context,
                      label: S.hrFieldLeaveType,
                      hint: S.hrNoLeaveTypesRead,
                    ),
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                    ),
                    dropdownColor: theme.colorScheme.surface,
                    items: [
                      for (final type in widget.types)
                        DropdownMenuItem(
                          value: type.id,
                          child: Text(
                            hrLeaveTypeName(type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _typeId = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HrDateField(
                    label: S.hrLeaveStartsOn,
                    value: _startsOn,
                    onChanged: (value) => setState(() => _startsOn = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HrDateField(
                    label: S.hrLeaveEndsOn,
                    value: _endsOn,
                    onChanged: (value) => setState(() => _endsOn = value),
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
                    ),
                  ),
                  if (_type?.requiresDocument ?? false) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _document,
                      style: const TextStyle(fontSize: AppFontSizes.size12_5),
                      decoration: adminDialogFieldDecoration(
                        context,
                        label: S.hrDocumentLabel,
                        hint: S.hrDocumentHint,
                        required: true,
                      ),
                    ),
                  ],
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
              saveKey: const Key('hr-leave-save'),
              saveLabel: S.hrBtnRequestLeave,
              savingLabel: S.hrBtnRequestLeave,
            ),
          ],
        ),
      ),
    );
  }
}
