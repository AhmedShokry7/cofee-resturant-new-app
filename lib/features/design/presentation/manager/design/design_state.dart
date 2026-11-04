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

  /// أقسام الصفحة الرئيسية بترتيبها المنشور؛ فارغة حين لا مستند يقرؤه الهاتف،
  /// فت رسمُها ترتيبَ الصفحة المكتوب في مصدرها.
  List<PublishedSection> get homeSections => design.homeSections;

  DesignState copyWith({PublishedDesign? design, bool? isLoaded}) => DesignState(
    design: design ?? this.design,
    isLoaded: isLoaded ?? this.isLoaded,
  );
}
