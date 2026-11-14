import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// عقد مستند التصميم بين اللوحة والهاتف.
///
/// حزمتان لا تستورد إحداهما الأخرى: الأدوار ومضاعفات الخط ومفاتيح الأقسام
/// مكتوبة مرة في محرّر الأدمن (`design_contract.dart`) ومرة في قارئ الزبون
/// (`published_design.dart`)، والقيمة التي يحفظها أحدهما قد لا يسمّيها الآخر.
/// التدقيق على النصّ نفسه — الحرس الذي يربط ما تنشره اللوحة بما يرسمه الهاتف.
///
/// خروجها عن التطابق ليس حادثًا يُصلح في صمت: مستند منشور بلون لا يعرفه
/// الهاتف يترك الزبون على شكله القديم، وقسم تنشره اللوحة لا يسمّيه الهاتف
/// لا يُرسم إطلاقًا، والموظف يرى في اللوحة أن النشر تمّ.
void main() {
  const adminContractPath =
      'app/admin_app/lib/features/visual_editor/domain/design_contract.dart';
  const customerModelPath =
      'lib/features/design/data/model/published_design.dart';

  test('الأدوار المكتوبة في المستند هي التي يقرأها الهاتف', () {
    expect(
      _customerRoles(_read(customerModelPath)),
      _adminRoles(_read(adminContractPath)),
      reason:
          'دور في عقد اللوحة لا يسمّيه قارئ الزبون: النشر يمرّ والقاعدة تكتبه '
          'والهاتف يتجاهله.',
    );
  });

  test('مضاعفات الخط أرقام واحدة في الطرفين', () {
    final admin = _adminFactors(_read(adminContractPath));
    final customer = _customerFactors(_read(customerModelPath));
    expect(customer.keys, admin.keys);
    for (final key in admin.keys) {
      expect(customer[key], admin[key], reason: 'مقياس `$key` اختلف بين الطرفين.');
    }
  });

  test('المستند الذي لم يُنشر بعد يُقرأ محايدًا في الحزمتين', () {
    // اللوحة تحفظ طبقة فارغة، والقارئ يجيب عنها بلا لون ولا مضاعف.
    expect(_read(adminContractPath), contains('static const DesignTheme none'));
    expect(_customerFactors(_read(customerModelPath)), contains('default'));
  });

  test('أنواع الأقسام التي ترسمها اللوحة هي التي يرسمها الهاتف', () {
    final adminTypes = _adminSectionTypes(_read(adminContractPath));
    final customerTypes = _customerSectionTypes(_read(customerModelPath));
    expect(adminTypes, isNotEmpty);
    for (final type in customerTypes) {
      expect(
        adminTypes,
        contains(type),
        reason: 'نوع يرسمه الهاتف ولا يكتبه محرّر الأدمن: قسم لا يصل إلى النشر.',
      );
    }
    expect(
      adminTypes.length,
      customerTypes.length,
      reason: 'نوع تكتبه اللوحة ولا يرسمه الهاتف: النشر يمرّ والقسم لا يُرسم.',
    );
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

Map<String, double> _adminFactors(String source) => _factors(
  _factorBlock(
    source,
    'static const Map<String, double> textFactors',
  ),
);

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

/// أنواع الأقسام لدى اللوحة: قائمة `sectionTypes` في العقد.
List<String> _adminSectionTypes(String source) => _stringsBetween(
  source,
  start: 'static const List<String> sectionTypes = [',
  end: '];',
);

/// أنواع الأقسام لدى الهاتف: ثوابت [DesignWidgetTypes]، بلا الصفحة نفسها.
List<String> _customerSectionTypes(String source) {
  final from = source.indexOf('abstract final class DesignWidgetTypes {');
  if (from < 0) throw StateError('لا DesignWidgetTypes — تغيّر شكل الملف.');
  final to = source.indexOf('}', from);
  if (to < 0) throw StateError('لا نهاية لـ DesignWidgetTypes.');
  return RegExp(r"= '([^']+)'")
      .allMatches(source.substring(from, to))
      .map((match) => match.group(1)!)
      .where((key) => key != 'page.home')
      .toList();
}

List<String> _stringsBetween(
  String source, {
  required String start,
  required String end,
}) {
  final from = source.indexOf(start);
  if (from < 0) throw StateError('لا `$start` في المصدر — تغيّر العقد.');
  final to = source.indexOf(end, from);
  if (to < 0) throw StateError('لا `$end` في المصدر — تغيّر العقد.');
  return RegExp(r"'([^']+)'")
      .allMatches(source.substring(from, to))
      .map((match) => match.group(1)!)
      .toList();
}
