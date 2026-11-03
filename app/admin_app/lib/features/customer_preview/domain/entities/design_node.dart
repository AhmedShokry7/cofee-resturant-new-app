/// عقدة في شجرة تصميم صفحة: نوع من [WidgetRegistry]، وقيم خصائصه، وأبناؤه.
///
/// الشجرة ثابتة: كل تعديل يرجع عقدة جديدة بدل أن يبدّل في مكانه، فيبقى Undo
/// والـ Redo نسخة محفوظة من المستند لا ترميمًا لقيمة تغيّرت.
///
/// قيم الخصائص أنواع يمكن تمثيلها في JSON فقط (نص، رقم، علم)، والمحرّر لا
/// يخزّن أرقامًا حرّة للمسافات والزوايا بل أسماء توكن، لأن رقمًا حرًا في
/// المستند المنشور يكسر شاشة لم تُختبر عليه.
class DesignNode {
  DesignNode({
    required this.id,
    required this.type,
    Map<String, Object?> properties = const <String, Object?>{},
    List<DesignNode> children = const <DesignNode>[],
    this.isVisible = true,
  }) : properties = Map<String, Object?>.unmodifiable(properties),
       children = List<DesignNode>.unmodifiable(children);

  /// معرّف ثابت للعقدة، وهو ما تشير إليه حدود التحديد ومؤشر الإفلات.
  final String id;

  /// نوع المكوّن، ومفتاحه مسجَّل في [WidgetRegistry] لا اسم صنف Dart.
  final String type;

  final Map<String, Object?> properties;
  final List<DesignNode> children;

  /// الإخفاء قرار في المستند لا حذف للعقدة: المقطع الذي يُخفى اليوم قد يعود
  /// غدًا ببياناته وترتيبه.
  final bool isVisible;

  Object? property(String key) => properties[key];

  String stringProperty(String key, {String fallback = ''}) =>
      properties[key] is String ? properties[key]! as String : fallback;

  bool boolProperty(String key, {bool fallback = false}) =>
      properties[key] is bool ? properties[key]! as bool : fallback;

  int intProperty(String key, {int fallback = 0}) =>
      properties[key] is int ? properties[key]! as int : fallback;

  DesignNode copyWith({
    String? id,
    String? type,
    Map<String, Object?>? properties,
    List<DesignNode>? children,
    bool? isVisible,
  }) {
    return DesignNode(
      id: id ?? this.id,
      type: type ?? this.type,
      properties: properties ?? this.properties,
      children: children ?? this.children,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  /// نسخة بخاصية واحدة مغايرة، بلا تعديل في مكانه.
  DesignNode withProperty(String key, Object? value) {
    final next = Map<String, Object?>.of(properties);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(properties: next);
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'type': type,
    'visible': isVisible,
    'properties': properties,
    'children': <Object?>[for (final child in children) child.toMap()],
  };

  /// قراءة مستند وصل من القاعدة أو من ملف.
  ///
  /// الصرامة هنا قبل النشر: شكل ناقص أو نوع غير معروف يرمي، فلا يُقبل منشور
  /// نصفه مكسور ثم يُحمَّل على شاشة الزبون.
  static DesignNode fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final type = map['type'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('عقدة بلا معرّف');
    }
    if (type is! String || type.isEmpty) {
      throw FormatException('العقدة $id بلا نوع');
    }
    final rawProperties = map['properties'];
    if (rawProperties != null && rawProperties is! Map) {
      throw FormatException('خصائص العقدة $id ليست قائمة قيم');
    }
    final rawChildren = map['children'];
    if (rawChildren != null && rawChildren is! List) {
      throw FormatException('أبناء العقدة $id ليسوا قائمة');
    }
    return DesignNode(
      id: id,
      type: type,
      isVisible: map['visible'] is bool ? map['visible']! as bool : true,
      properties: <String, Object?>{
        if (rawProperties is Map<Object?, Object?>)
          for (final entry in rawProperties.entries)
            if (entry.key is String && _isJsonValue(entry.value))
              entry.key! as String: entry.value,
      },
      children: <DesignNode>[
        if (rawChildren is List<Object?>)
          for (final child in rawChildren)
            if (child is Map<Object?, Object?>) DesignNode.fromMap(child),
      ],
    );
  }

  static bool _isJsonValue(Object? value) =>
      value is String || value is bool || value is int || value is double;
}
