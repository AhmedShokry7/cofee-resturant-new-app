import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// قناة المعاينة عقد من طرفين لا يستورد أحدهما الآخر: أنواع الرسائل مكتوبة
/// في محرّر الأدمن وفي تطبيق العميل، و`PreviewMessage.fromJson` يرفض أي نوع
/// لا يعرفه. انزياح حرف واحد في الطرفين يُسقط الرسالة بصمت، فيبقى المحرّر
/// ينتظر معاينة لا تتحرك. هذا الحرس يقرأ النصّين ويقارن قيم الأسلاك.
void main() {
  const adminPath =
      'app/admin_app/lib/features/visual_editor/domain/visual_editor_models.dart';
  const customerPath = 'lib/core/preview/preview_bridge.dart';

  test('أنواع رسائل المعاينة متطابقة في الأدمن والعميل', () {
    final admin = _messageTypes(
      _read(adminPath),
      'enum VisualEditorMessageType {',
    );
    final customer = _messageTypes(
      _read(customerPath),
      'enum PreviewMessageType {',
    );

    expect(admin, isNotEmpty);
    expect(customer, admin);
    expect(customer, contains('SET_LANGUAGE'));
    expect(customer, contains('SET_THEME_MODE'));
    expect(customer, contains('SET_INTERACTIVE_MODE'));
  });
}

String _read(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) {
    throw StateError('$relativePath مفقود — لا عقد يمكن مقارنته.');
  }
  return file.readAsStringSync();
}

List<String> _messageTypes(String source, String start) {
  final from = source.indexOf(start);
  if (from < 0) throw StateError('لا `$start` في المصدر — تغيّر العقد.');
  final to = source.indexOf('}', from);
  if (to < 0) throw StateError('لا نهاية للتعداد بعد `$start`.');
  return RegExp(r"\('([A-Z_]+)'\)")
      .allMatches(source.substring(from, to))
      .map((match) => match.group(1)!)
      .toList();
}
