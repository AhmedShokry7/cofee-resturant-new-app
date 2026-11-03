import 'package:flutter/widgets.dart' show IconData;

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/registry/design_property.dart';

/// كم يملك الموظف في هذا المكوّن.
enum WidgetEditLevel {
  /// يُضاف ويُسحب ويُخفى وتُعدَّل كل خصائصه.
  editable,

  /// شكله قابل للتعديل فقط: خصائص مسماة ومنطقه كما هو.
  partial,

  /// موجود لأن التطبيق يعمل به، لا لأن الموظف وضعه: لا يُحذف ولا يُخفى.
  locked,
}

/// عائلة المكوّن في مكتبة العناصر.
enum WidgetCategory { layout, content, restaurant, navigation }

/// تعريف مكوّن واحد يستطيع المحرّر عرضه ورسمه.
///
/// السجل عند المطوّر وحده: كل نوع هنا له شاشة رسم حقيقية في `DesignRenderer`
/// وخصائص محددة ومصدر بيانات مسموح وإجراء مسجَّل. الموظف لا يكتب Dart ولا
/// يخترع نوعًا، ولا يغيّر وظيفة زر — يغيّر مكانه ونصه ولونه فقط.
class WidgetSpec {
  const WidgetSpec({
    required this.type,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.level,
    this.childTypes = const <String>[],
    this.parentTypes = const <String>[],
    this.properties = const <DesignPropertySpec>[],
    this.actionKeys = const <String>[],
    this.dataSourceKeys = const <String>[],
    this.mandatory = false,
    this.canHaveChildren = false,
    this.version = 1,
  });

  /// مفتاح النوع في المستند، مثل `section.banner_carousel`.
  final String type;

  final L10nText name;
  final L10nText description;
  final WidgetCategory category;
  final IconData icon;
  final WidgetEditLevel level;

  /// أنواع الأبناء المسموحة داخل هذا المكوّن. نوع لا تُذكر أنواعه لا يقبل ابنًا.
  final List<String> childTypes;

  /// أنواع الآباء التي يقبل هذا المكوّن ابنًا عليها. قائمة أباء فارغة تعني أنه
  /// جذر صفحة ولا يُسحب إلى داخل أحد.
  final List<String> parentTypes;

  final List<DesignPropertySpec> properties;

  /// مفاتيح الإجراءات المسموحة لهذا المكوّن، من السجل وحده.
  final List<String> actionKeys;

  /// مصادر البيانات التي يقبلها هذا المكوّن.
  final List<String> dataSourceKeys;

  /// مكوّن أساس لا يُخفى ولا يُحذف (شريط التبويبات، رأس الصفحة).
  final bool mandatory;

  /// حاوية تقبل أبناء يُسحبون إليها؛ لا تُخلط بمكوّن يرسم ابنه داخله بتركيبة
  /// ثابتة لا يملكها المحرّر.
  final bool canHaveChildren;

  final int version;

  bool get isLeaf => !canHaveChildren;

  Map<String, Object?> get defaults => <String, Object?>{
    for (final spec in properties)
      if (spec.defaultValue != null) spec.key: spec.defaultValue,
  };

  DesignPropertySpec? property(String key) {
    for (final spec in properties) {
      if (spec.key == key) return spec;
    }
    return null;
  }

  bool allowsChild(String childType) =>
      canHaveChildren && childTypes.contains(childType);

  bool allowsParent(String parentType) =>
      parentTypes.isEmpty ? false : parentTypes.contains(parentType);

  String nameOf(AppLanguage language) => name.of(language);
}
