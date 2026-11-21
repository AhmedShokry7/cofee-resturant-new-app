import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';

Future<void> showVisualEditorJsonEditor(
  BuildContext context,
  VisualEditorCubit cubit,
) async {
  final controller = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(cubit.currentDesignDocument),
  );
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('تحرير تصميم التطبيق (JSON)'),
        content: SizedBox(
          width: 860,
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'عدّل ملف التصميم الذي يطبقه تطبيق العميل. التغييرات تُراجع وتظهر في المعاينة؛ هذا لا يحرر شيفرة Dart.',
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(controller.text);
                if (decoded is! Map) {
                  setDialogState(() => error = 'يجب أن يكون المحتوى كائن JSON.');
                  return;
                }
                final validation = cubit.importDesignDocument(
                  Map<String, dynamic>.from(decoded),
                );
                if (validation != null) {
                  setDialogState(() => error = 'ملف التصميم غير صالح: $validation');
                  return;
                }
                Navigator.pop(dialogContext);
              } on FormatException catch (exception) {
                setDialogState(() => error = 'خطأ في صيغة JSON: ${exception.message}');
              } catch (exception) {
                setDialogState(() => error = 'تعذر تطبيق التصميم: $exception');
              }
            },
            child: const Text('تطبيق على المعاينة'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}
