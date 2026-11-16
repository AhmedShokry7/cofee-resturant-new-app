import 'package:flutter/foundation.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';

/// الشكل الذي يرسم به الهاتف هذه الجلسة.
///
/// يحمل المستند كله لا طبقة ألوانه: الأقسام المنشورة شكلٌ بقدر ما اللون شكل،
/// فتبقى قراءتهما في مكان واحد ويحدثان معًا لا قسم قبل اللون.
@immutable
class DesignState {
  const DesignState({
    this.design = PublishedDesign.none,
    this.isLoaded = false,
  });

  final PublishedDesign design;

  /// تمت قراءة المنشور — أو تعذّرت وبقي شكل اليوم. تفرّق شاشةٌ تحتاج أن تعرف
  /// هل انتظرته أم لا.
  final bool isLoaded;

  PublishedTheme get theme => design.theme;

  double get textFactor => design.theme.textFactor;

  /// اسم التطبيق كما نصّه الموظف من المحرر، أو null ليُسقط على اسم الكود.
  String? get appNameAr => design.theme.appNameAr;

  String? get appNameEn => design.theme.appNameEn;

  /// رابط لوجو التطبيق كما رفعه الموظف، أو null للوجو المضمّن.
  String? get logoUrl => design.theme.logoUrl;

  /// اسم الهوية للغة المعروضة أو null.
  String? brandName(bool isArabic) =>
      design.theme.brandName(isArabic: isArabic);

  /// أقسام الصفحة الرئيسية بترتيبها المنشور؛ فارغة حين لا مستند يقرؤه الهاتف،
  /// فت رسمُها ترتيبَ الصفحة المكتوب في مصدرها.
  List<PublishedSection> get homeSections => design.homeSections;

  /// أقسام صفحة التصنيفات المنشورة؛ فارغة حين لا صفحة لها في المستند.
  List<PublishedSection> get categoriesSections => design.categoriesSections;

  /// أقسام أي صفحة أخرى بترتيبها المنشور؛ فارغة حين لا مستند يحملها،
  /// فترسم الشاشة كما هي بلا محتوى مضاف.
  List<PublishedSection> pageSections(String pageId) =>
      design.sectionsFor(pageId);

  DesignState copyWith({PublishedDesign? design, bool? isLoaded}) => DesignState(
    design: design ?? this.design,
    isLoaded: isLoaded ?? this.isLoaded,
  );
}
