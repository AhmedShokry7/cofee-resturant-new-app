import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حرس ترتيب الأقسام على الصفحة الرئيسية.
///
/// مستند التصميم الافتراضي في المحرّر يدّعي أنه «ترتيب العميل الحرفي كما هو
/// اليوم»، وتطبيق العميل يرسم ترتيبه ثابتًا في المصدر. لا شيء يربط الادعاءين:
/// ملفان في حزمتين لا تستورد إحداهما الأخرى، فالتدقيق على النص نفسه لا على
/// الاستيراد.
///
/// تغيير أحد الطرفين دون الآخر يكسر الوعد الأول في الاستوديو — أن تصميم اليوم
/// هو التصميم عند بدء النظام — فيفشل هذا الاختبار، لا شاشة الزبون.
void main() {
  const customerBodyPath =
      'lib/features/home/presentation/views/widgets/home_page_body.dart';
  const registryPath =
      'app/admin_app/lib/features/customer_preview/domain/registry/widget_registry.dart';

  test('ترتيب أقسام العميل في المصدر لم يتغيّر', () {
    expect(
      _customerHomeSections(_read(customerBodyPath)),
      _expectedCustomerSections,
      reason: 'ترتيب الصفحة الرئيسية تغيّر في المصدر؛ القرار قرار لا حادث — '
          'حدّث التوقعين هنا معًا بعد أن تقرّر الانحراف عن تصميم اليوم.',
    );
  });

  test('المستند الافتراضي يرسم أقسام العميل الثمانية بالترتيب نفسه', () {
    final document = _documentHomeSections(_read(registryPath));

    expect(document, _expectedDocumentTypes);
    expect(
      document,
      hasLength(_expectedCustomerSections.length),
      reason: 'قسم في العميل بلا عقدة في المستند، أو العكس: المحرّر يعرض شاشة '
          'لا يملك العميل أن يرسمها.',
    );
  });

  test('عقدتا الشريط تتمايزان بمصدر البيانات لا بالنوع', () {
    // `HomePopularSection` و`HomeRecommendationsSection` نوع واحد في السجل،
    // فالفرق كله في الخاصية؛ لو توحد المصدران صار القسمان نسخة واحدة.
    final source = _read(registryPath);
    expect(
      RegExp(r"'dataSource': DataSourceRegistry\.(\w+)")
          .allMatches(source)
          .map((match) => match.group(1))
          .take(2)
          .toList(),
      containsAllInOrder(<String>['featured', 'recommendations']),
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

/// الأنواع المقابلة في سجل المكونات بالترتيب نفسه؛ `productStrip` يتكرر لأن
/// الأكثر طلبًا والترشيحات شريطا منتجات يختلفان في مصدر البيانات.
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

/// أقسام جسم الصفحة الرئيسية بترتيبها، من قائمة children الحقيقية.
///
/// `HomeSection` مستبعد: غلاف الحشو حول القسم لا القسم، ولولا الاستبعاد ظهر
/// ثمانية مرات زائدة. نقطة البدء `HomeSection.bodyPadding` لا `children: [`,
/// لأن في الجسم قائمة children أخرى قبلها تخص شاشة الخطأ.
List<String> _customerHomeSections(String source) {
  final start = source.indexOf('padding: HomeSection.bodyPadding');
  if (start < 0) {
    throw StateError('لا قائمة أقسام في المصدر — تغيّر شكل الجسم.');
  }
  final end = source.indexOf('],', start);
  final body = source.substring(start, end < 0 ? source.length : end);
  return RegExp(r'\b(Home(?!Section)[A-Za-z]+)\(')
      .allMatches(body)
      .map((match) => match.group(1)!)
      .toList();
}

/// أنواع عقد الصفحة الرئيسية في `defaultDocument()` بترتيب بنائها.
///
/// المعرّف يميّز العقدة: كل عقد الصفحة الرئيسية في المستند تسمّى `home_*`.
List<String> _documentHomeSections(String source) {
  final start = source.indexOf('static DesignDocument defaultDocument()');
  if (start < 0) {
    throw StateError('لا defaultDocument() في السجل — الحرس بلا ما يقارنه.');
  }
  final end = source.indexOf('final categories = node(', start);
  final home = source.substring(start, end < 0 ? source.length : end);
  return RegExp(r"node\(\s*WidgetTypes\.(\w+),\s*'home_")
      .allMatches(home)
      .map((match) => match.group(1)!)
      .toList();
}
