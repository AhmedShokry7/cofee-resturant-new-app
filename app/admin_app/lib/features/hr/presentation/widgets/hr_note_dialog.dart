import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// حوار سبب واحد تُراجع به سطور HR: اعتماد، رفض، إلغاء، عكس تسوية.
///
/// أكثر دالة في 212 تطلب `note` أو `reason` وترفض الفراغ، فالحقل هنا إلزامي
/// افتراضًا: القرار بلا سببه يُرفض في القاعدة، وحوارٌ يسمح بالفراغ يبيع المدير
/// محاولة تخفق. يُرجع النص الذي كُتب، أو null إذا أُغلق بلا قرار.
Future<String?> showHrNoteDialog(
  BuildContext context, {
  required String title,
  required String saveLabel,
  String? question,
  String? noteLabel,
  bool noteRequired = true,
}) => showDialog<String>(
  context: context,
  builder: (dialogContext) => _HrNoteDialog(
    title: title,
    question: question,
    noteLabel: noteLabel ?? S.hrReasonLabel,
    saveLabel: saveLabel,
    noteRequired: noteRequired,
  ),
);

/// نص السبب كما كتبه المدير، مع التحقق من الفراغ قبل إرسال القرار.
class _HrNoteDialog extends StatefulWidget {
  const _HrNoteDialog({
    required this.title,
    required this.noteLabel,
    required this.saveLabel,
    required this.noteRequired,
    this.question,
  });

  final String title;
  final String? question;
  final String noteLabel;
  final String saveLabel;
  final bool noteRequired;

  @override
  State<_HrNoteDialog> createState() => _HrNoteDialogState();
}

class _HrNoteDialogState extends State<_HrNoteDialog> {
  final TextEditingController _note = TextEditingController();
  bool _missing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final text = _note.text.trim();
    if (widget.noteRequired && text.isEmpty) {
      setState(() => _missing = true);
      return;
    }
    Navigator.of(context).pop(text);
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
              title: widget.title,
              subtitle: widget.question,
              onClose: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _note,
                minLines: 3,
                maxLines: 6,
                style: TextStyle(fontSize: AppFontSizes.size12_5),
                decoration: adminDialogFieldDecoration(
                  context,
                  label: widget.noteLabel,
                  hint: S.hrReasonHint,
                  required: widget.noteRequired,
                ),
              ),
            ),
            if (_missing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AdminErrorBanner(message: S.hrReasonMissing),
              ),
            AdminDialogFooter(
              saving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
              saveKey: const Key('hr-note-save'),
              saveLabel: widget.saveLabel,
              savingLabel: widget.saveLabel,
              cancelLabel: S.cancel,
            ),
          ],
        ),
      ),
    );
  }
}
