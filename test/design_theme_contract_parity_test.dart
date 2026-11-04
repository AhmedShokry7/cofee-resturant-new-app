import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// عقد طبقة الشكل بين اللوحة والهاتف.
///
/// حزمتان لا تستورد إحداهما الأخرى: الأدوار ومضاعفات الخط مكتوبة مرة في محرّر
/// الأدمن ومرة في قارئ الزبون، والقيمة التي يحفظها أحدهما قد لا يسمّيها الآخر.
/// التدقيق على النصّ نفسه — الحرس الذي يربط ترتيب أقسام الصفحة الرئيسية بصيغة
/// هذه الاختبارات.
///
/// خروجها عن التطابق ليس حادثًا يُصلح في صمت: مستند منشور بلون لا يعرفه الهاتف
/// يترك الزبون على شكله القديم، والموظف يرى في اللوحة أن النشر تمّ.
void main() {
  const adminThemePath =
      'app/admin_app/lib/features/customer_preview/domain/entities/design_theme.dart';
  const customerModelPath =
      'lib/features/design/data/model/published_design.dart';

  test('الأدوار المكتوبة في المستند هي التي يقرأها الهاتف', () {
    expect(
      _customerRoles(_read(customerModelPath)),
      _adminRoles(_read(adminThemePath)),
      reason:
          'دور في عقد اللوحة لا يسمّيه قارئ الزبون: النشر يمرّ والقاعدة تكتبه '
          'والهاتف يتجاهله.',
    );
  });

  test('مضاعفات الخط أرقام واحدة في الطرفين', () {
    final admin = _adminFactors(_read(adminThemePath));
    final customer = _customerFactors(_read(customerModelPath));
    expect(customer.keys, admin.keys);
    for (final key in admin.keys) {
      expect(customer[key], admin[key], reason: 'مقياس `$key` اختلف بين الطرفين.');
    }
  });

  test('المستند الذي لم يُنشر بعد يُقرأ محايدًا في الحزمتين', () {
    // اللوحة تحفظ طبقة فارغة، والقارئ يجيب عنها بلا لون ولا مضاعف.
    expect(_read(adminThemePath), contains('static const DesignTheme none'));
    expect(_customerFactors(_read(customerModelPath)), contains('default'));
  });
}

String _read(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) {
    throw StateError('$relativePath مفقود — الحرس بلا ما يقارنه.');
  }
  return file.readAsStringSync();
}

/// أدوار اللوحة: المفاتيح الأولى في تعداد [DesignColorRole].
List<String> _adminRoles(String source) => _roles(
  source,
  start: 'enum DesignColorRole {',
  end: 'const DesignColorRole(this.key',
);

/// أدوار الهاتف: المفاتيح الأولى في تعداد [ThemeColorRole].
List<String> _customerRoles(String source) => _roles(
  source,
  start: 'enum ThemeColorRole {',
  end: 'const ThemeColorRole(this.key',
);

List<String> _roles(
  String source, {
  required String start,
  required String end,
}) {
  final from = source.indexOf(start);
  final to = source.indexOf(end, from);
  if (from < 0 || to < 0) {
    throw StateError('لا تعداد أدوار بين `$start` و`$end` — تغيّر شكل الملف.');
  }
  return RegExp(r"^\s*(\w+)\('([^']+)'", multiLine: true)
      .allMatches(source.substring(from, to))
      .map((match) => match.group(2)!)
      .toList();
}

Map<String, double> _adminFactors(String source) {
  final block = _factorBlock(
    source,
    'static const Map<String, double> textFactors',
  );
  // `defaultKey: 1` مفتاحٌ باسم ثابت في اللوحة، لا نصّ.
  return _factors(block.replaceAll('defaultKey:', "'default':"));
}

Map<String, double> _customerFactors(String source) => _factors(
  _factorBlock(
    source,
    'static const Map<String, double> _textFactors',
  ),
);

String _factorBlock(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) throw StateError('لا `$marker` في المصدر — تغيّر العقد.');
  final end = source.indexOf('};', start);
  return source.substring(start, end < 0 ? source.length : end);
}

Map<String, double> _factors(String block) {
  final pairs = RegExp(r"'(\w+)':\s*([0-9.]+)")
      .allMatches(block)
      .map((match) => MapEntry(match.group(1)!, double.parse(match.group(2)!)))
      .toList();
  if (pairs.isEmpty) throw StateError('لا مضاعفات خط في المقطع.');
  return Map<String, double>.fromEntries(pairs);
}
