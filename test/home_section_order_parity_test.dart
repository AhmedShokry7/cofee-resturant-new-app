import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حرس ترتيب الأقسام على الصفحة الرئيسية.
///
/// «تصميم اليوم» في المحرّر (`DesignDocumentCodec.defaultHomeNodes`) يدّعي
/// أنه ترتيب العميل الحرفي كما هو اليوم، وتطبيق العميل يرسم ترتيبه ثابتًا في
/// مصدره (`_defaultHomeSections`). لا شيء يربط الادعاءين: ملفان في حزمتين
/// لا تستورد إحداهما الأخرى، فالتدقيق على النص نفسه لا على الاستيراد.
///
/// تغيير أحد الطرفين دون الآخر يكسر الوعد الأول في الاستوديو — أن تصميم
/// اليوم هو التصميم عند بدء النظام — فيفشل هذا الاختبار، لا شاشة الزبون.
void main() {
  const customerBodyPath =
      'lib/features/home/presentation/views/widgets/home_page_body.dart';
  const codecPath =
      'app/admin_app/lib/features/visual_editor/domain/design_document_codec.dart';

  test('ترتيب أقسام العميل في المصدر لم يتغيّر', () {
    expect(
      _customerHomeSections(_read(customerBodyPath)),
      _expectedCustomerSections,
      reason: 'ترتيب الصفحة الرئيسية تغيّر في المصدر؛ القرار قرار لا حادث — '
          'حدّث التوقعين هنا معًا بعد أن تقرّر الانحراف عن تصميم اليوم.',
    );
  });

  test('مستند تصميم اليوم يرسم أقسام العميل الثمانية بالترتيب نفسه', () {
    final document = _documentHomeTypes(_read(codecPath));

    expect(document, _expectedDocumentTypes);
    expect(
      document,
      hasLength(_expectedCustomerSections.length),
      reason: 'قسم في العميل بلا عقدة في المستند، أو العكس: المحرّر يعرض شاشة '
          'لا يملك العميل أن يرسمها.',
    );
  });

  test('عقدتا الشريط تتمايزان بمصدر البيانات لا بالنوع', () {
    // شريطا «الأكثر طلبًا» و«ترشيحات لك» نوع واحد في المستند، فالفرق كله
    // في مصدر البيانات؛ لو توحد المصدران صار القسمان نسخة واحدة.
    final sources = _documentDataSources(_read(codecPath));
    expect(
      sources,
      containsAllInOrder(<String>['featured', 'recommendations']),
      reason: 'مصدرا الشريطين غابا أو انعكسا في تصميم اليوم.',
    );
  });
}

const _expectedCustomerSections = <String>[
  'HomeHeader',
  'HomeSearchBar',
  'HomeBannerSection',
  'HomeCategoriesSection',
  'HomePopularSection',
  'HomeSingleBannerSection',
  'HomeRecommendationsSection',
  'HomeBundlesSection',
];

/// الأنواع بمفاتيح المحرّر بالترتيب نفسه؛ `productStrip` يتكرر لأن الأكثر
/// طلبًا والترشيحات شريطا منتجات يختلفان في مصدر البيانات.
const _expectedDocumentTypes = <String>[
  'header',
  'searchBar',
  'bannerCarousel',
  'categoryList',
  'productStrip',
  'promoBanner',
  'productStrip',
  'bundleList',
];

String _read(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) {
    throw StateError(
      '$relativePath مفقود — الحرس بلا ما يقرأه، فالتطابق غير مضمون.',
    );
  }
  return file.readAsStringSync();
}

/// أقسام جسم الصفحة الرئيسية بترتيبها، من قائمة الافتراضي المكتوبة في المصدر.
///
/// `HomeSection` مستبعد: غلاف الحشو حول القسم لا القسم، ولولا الاستبعاد ظهر
/// ثمانية مرات زائدة. القائمة التي تُقرأ هي `_defaultHomeSections` وحدها — ما
/// يرسمه الهاتف حين لا مستند منشور — لا ما يُبنى من المستند وقت الشاشة.
List<String> _customerHomeSections(String source) {
  final start = source.indexOf('const List<Widget> _defaultHomeSections');
  if (start < 0) {
    throw StateError('لا قائمة أقسام افتراضية في المصدر — تغيّر شكل الجسم.');
  }
  final end = source.indexOf('];', start);
  final body = source.substring(start, end < 0 ? source.length : end);
  return RegExp(r'\b(Home(?!Section)[A-Za-z]+)\(')
      .allMatches(body)
      .map((match) => match.group(1)!)
      .toList();
}

/// أنواع `defaultHomeNodes` بترتيبها في عقد «تصميم اليوم».
List<String> _documentHomeTypes(String source) {
  final block = _blockBetween(
    source,
    start: 'static const List<(String, String?)> defaultHomeNodes = [',
    end: '];',
  );
  return RegExp(r"\('(\w+)'")
      .allMatches(block)
      .map((match) => match.group(1)!)
      .toList();
}

/// مصادر البيانات في `defaultHomeNodes`، بترتيبها — مرجعية `DesignContract`.
List<String> _documentDataSources(String source) {
  final block = _blockBetween(
    source,
    start: 'static const List<(String, String?)> defaultHomeNodes = [',
    end: '];',
  );
  return RegExp(r'DesignContract\.(\w+)')
      .allMatches(block)
      .map((match) => match.group(1)!)
      .toList();
}

String _blockBetween(
  String source, {
  required String start,
  required String end,
}) {
  final from = source.indexOf(start);
  if (from < 0) throw StateError('لا `$start` في المصدر — تغيّر العقد.');
  final to = source.indexOf(end, from);
  if (to < 0) throw StateError('لا `$end` في المصدر — تغيّر العقد.');
  return source.substring(from, to);
}
