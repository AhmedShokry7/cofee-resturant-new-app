/// مُسلسل مستند التصميم: بين شجرة المحرّر الداخلية والمستند المنشور.
///
/// المحرّر يعمل بمفاتيح داخلية قصيرة (`bannerCarousel`)، والمستند المنشور
/// يعمل بمفاتيح العقد (`section.banner_carousel`) التي يرسمها الهاتف ويدققها
/// `core.app_design_is_valid`. التحويل هنا مرة واحدة: كل ما يُحفظ أو يُنشر
/// أو يُقرأ يمر عبر هذا الملف، فلا تنزيح عقد في مستودع أو cubit.
///
/// أنواع لا يرسمها الهاتف بعد (text، button، image…) تُكتب بمفتاحها الداخلي:
/// المدقق لا يسمّي الأنواع (قرار 226)، والهاتف يسقطها من رسمه دون أن يُهجر
/// المستند — تركيب معلن، لا قالب وهمي يدّعي رندرًا غير موجود.
library;

import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

class DesignDocumentCodec {
  DesignDocumentCodec._();

  /// مفاتيح المحرّر الداخلية → مفاتيح العقد كما يرسمها الهاتف.
  static const Map<String, String> phoneTypes = {
    'header': DesignContract.header,
    'searchBar': DesignContract.searchBar,
    'bannerCarousel': DesignContract.bannerCarousel,
    'categoryList': DesignContract.categoryList,
    'promoBanner': DesignContract.promoBanner,
    'productStrip': DesignContract.productStrip,
    'bundleList': DesignContract.bundleList,
  };

  /// مصادر البيانات: المفاتيح الداخلية → مفاتيح العقد.
  static const Map<String, String> phoneDataSources = {
    'featured': DesignContract.featured,
    'recommendations': DesignContract.recommendations,
  };

  /// مفتاح العقد لنوع داخلي، أو النوع نفسه لما لا يرسمه الهاتف.
  static String contractType(String internal) =>
      phoneTypes[internal] ?? internal;

  /// المفتاح الداخلي لمفتاح عقد (للقراءة الراجعة من مستند).
  static String internalType(String contract) {
    for (final entry in phoneTypes.entries) {
      if (entry.value == contract) return entry.key;
    }
    return contract;
  }

  /// مصدر بيانات بمفتاح العقد، أو القيمة الأصلية لغير المعرّف.
  static String? contractDataSource(Object? internal) {
    if (internal is! String || internal.isEmpty) return null;
    return phoneDataSources[internal] ?? internal;
  }

  static String? internalDataSource(Object? contract) {
    if (contract is! String || contract.isEmpty) return null;
    for (final entry in phoneDataSources.entries) {
      if (entry.value == contract) return entry.key;
    }
    return contract;
  }

  // ------------------------------------------------------------------ كتابة

  /// عقدة مستند لمكوّن واحد: معرفّه ثابتًا، ونوعه بمفتاح العقد، وخصائصه
  /// أعدادًا أولية فقط — كما تشترط `app_design_node_check` (226).
  static Map<String, dynamic> node(EditableComponent component) {
    final properties = <String, dynamic>{};
    component.properties.forEach((key, value) {
      if (!_isScalar(value)) return;
      if (key == 'dataSource') {
        properties[key] = contractDataSource(value);
      } else if (key == 'visible') {
        // الظهور حقل العقدة نفسه لا خاصية.
      } else {
        properties[key] = value;
      }
    });
    return {
      'id': component.componentId,
      'type': contractType(component.componentType),
      'visible': component.properties['visible'] is bool
          ? component.properties['visible'] as bool
          : true,
      'properties': properties,
    };
  }

  /// المستند كله بترتيب الصفحات ومكوّناتها.
  static Map<String, dynamic> document(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) {
    // طبقة محايدة تعني غياب المفتاح كله، لا `"theme": null` — المدقق الحي
    // يفرّق بين JSON null وكائن، والفارغ غيابٌ لا طبقة.
    final themeJson = theme.toJson();
    return {
      'schema_version': DesignContract.readableSchemaVersion,
      if (themeJson != null) 'theme': themeJson,
      'pages': [
        for (final entry in componentsByPage.entries)
          if (entry.value.isNotEmpty)
            {
              // مفاتيح صفحات المحرّر هي مفاتيح العقد نفسها (المدقق يقبلها
              // بالحرف). `page.home` في الجذر هو النوع كما يقرؤه الهاتف.
              'page': entry.key,
              'root': {
                // الجذر عقدة كاملة لدى المدقق الحي: بمعرفّ فريد عبر المستند.
                'id': 'root_${entry.key}',
                'type': DesignContract.pageHome,
                'children': [
                  for (final component in entry.value) node(component),
                ],
              },
            },
      ],
    };
  }

  // ------------------------------------------------------------------ قراءة

  /// مكوّنات مستند محفوظة كما كُتبت، بترتيبها.
  static List<EditableComponent> parsePage(
    String pageId,
    Object? children,
  ) {
    final components = <EditableComponent>[];
    if (children is! List) return components;
    for (var index = 0; index < children.length; index++) {
      final raw = children[index];
      if (raw is! Map) continue;
      final id = raw['id'];
      final type = raw['type'];
      if (id is! String || id.isEmpty) continue;
      if (type is! String || type.isEmpty) continue;
      final properties = raw['properties'] is Map
          ? Map<String, dynamic>.from(raw['properties'] as Map)
          : <String, dynamic>{};
      // المصدر يعود بمفتاح العقد؛ نعيده داخليًا ليصل إلى المحرّر الذي كتبه،
      // ونجيب عن النوع غير المسمّى في السجل بترتيبه المكتوب لا بسجل مختلق.
      final internal = internalType(type);
      final entry = _registry[internal];
      if (properties['dataSource'] != null) {
        properties['dataSource'] =
            internalDataSource(properties['dataSource']) ?? '';
      }
      properties['visible'] = raw['visible'] is bool
          ? raw['visible'] as bool
          : true;
      components.add(
        EditableComponent(
          componentId: id,
          componentType: internal,
          pageId: pageId,
          index: index,
          classification:
              entry?.classification ?? ComponentClassification.editable,
          properties: properties,
          defaultValues: entry?.defaultValues ?? const {},
          validationRules: entry?.validationRules ?? const {},
          allowedOperations: entry?.allowedOperations ??
              const ['reorder', 'hide'],
          version: 1,
        ),
      );
    }
    return components;
  }

  /// صفحات مستند كامل → مكوّنات لكل صفحة.
  static Map<String, List<EditableComponent>> parseDocument(Object? raw) {
    final result = <String, List<EditableComponent>>{};
    if (raw is! Map) return result;
    final pages = raw['pages'];
    if (pages is! List) return result;
    for (final page in pages) {
      if (page is! Map) continue;
      final pageId = page['page'];
      if (pageId is! String) continue;
      final root = page['root'];
      if (root is! Map) continue;
      result[pageId] = parsePage(pageId, root['children']);
    }
    return result;
  }

  /// طبقة الشكل من مستند.
  static DesignTheme themeOf(Object? raw) =>
      DesignTheme.fromJson(raw is Map ? raw['theme'] : null);

  /// مستند «تصميم اليوم»: ترتيب الصفحة كما هو مكتوب في مصدر العميل
  /// (`_defaultHomeSections` هناك)، ليبدأ المحرّر منه حين لا مسودة محفوظة.
  ///
  /// الأنواع بمفاتيح المحرّر، والمصدر يفّرق شريطي المنتج بالبيانات لا بالنوع.
  /// النوعان نصّ عمدًا: النصّ هو العقدة التي يقرؤها حرس التطابق من هذا الملف.
  static const List<(String, String?)> defaultHomeNodes = [
    ('header', null),
    ('searchBar', null),
    ('bannerCarousel', null),
    ('categoryList', null),
    ('productStrip', DesignContract.featured),
    ('promoBanner', null),
    ('productStrip', DesignContract.recommendations),
    ('bundleList', null),
  ];

  /// مكوّنات «تصميم اليوم» كما تُبنى لشجرة المحرّر، من السجل عند تهيئته.
  static List<EditableComponent> defaultHomeComponents() => [
    for (var index = 0; index < defaultHomeNodes.length; index++)
      _defaultComponent(defaultHomeNodes[index], index),
  ];

  static EditableComponent _defaultComponent(
    (String, String?) entry,
    int index,
  ) {
    final type = entry.$1;
    final registryEntry = _registry[type];
    return EditableComponent(
      componentId: 'home_${type}_$index',
      componentType: type,
      pageId: 'home',
      index: index,
      classification:
          registryEntry?.classification ?? ComponentClassification.editable,
      properties: {
        ...?registryEntry?.defaultValues,
        'visible': true,
        if (entry.$2 != null) 'dataSource': entry.$2,
      },
      defaultValues: registryEntry?.defaultValues ?? const {},
      validationRules: registryEntry?.validationRules ?? const {},
      allowedOperations:
          registryEntry?.allowedOperations ?? const ['reorder', 'hide'],
      version: 1,
    );
  }

  // ------------------------------------------------------------ التحقق الحي

  /// أول عيب في المستند بنفس رموز `core.app_design_is_valid`، أو null.
  ///
  /// تحقق محلي قبل النشر ليُظهر الخطأ في المحرّر لا عند القاعدة؛ العدسة
  /// الأخيرة تبقى الـ RPC التي ترفض قبل أي كتابة.
  static String? validate(Map<String, dynamic> document) {
    final version = document['schema_version'];
    if (version is! num || version < 1 || version > 2) return 'schema_version';
    final pages = document['pages'];
    if (pages is! List || pages.isEmpty) return 'pages';
    if (pages.length > 7) return 'page_count';

    final ids = <String>{};
    for (final page in pages) {
      if (page is! Map) return 'page_entry';
      final pageKey = page['page'];
      if (pageKey is! String || !DesignContract.pageKeys.contains(pageKey)) {
        return 'page_key';
      }
      final root = page['root'];
      if (root is! Map) return 'root';
      final badNode = _validateNode(root, 1, ids);
      if (badNode != null) return badNode;
    }
    return null;
  }

  static String? _validateNode(Object? node, int depth, Set<String> ids) {
    if (node is! Map) return 'node';
    if (depth > 12) return 'depth';
    final id = node['id'];
    if (id is! String || id.isEmpty) return 'node_id';
    if (!ids.add(id)) return 'node_duplicate';
    final type = node['type'];
    if (type is! String || type.isEmpty) return 'node_type';
    final visible = node['visible'];
    if (visible != null && visible is! bool) return 'visible';
    final properties = node['properties'];
    if (properties != null) {
      if (properties is! Map) return 'properties';
      for (final value in properties.values) {
        if (!_isScalar(value)) return 'property_value';
      }
    }
    final children = node['children'];
    if (children != null) {
      if (children is! List) return 'children';
      for (final child in children) {
        final bad = _validateNode(child, depth + 1, ids);
        if (bad != null) return bad;
      }
    }
    if (ids.length > 400) return 'node_count';
    return null;
  }

  static bool _isScalar(Object? value) =>
      value is String || value is num || value is bool;

  /// مدخل السجل للمكوّنات: يُغذي من ComponentRegistry عند التهيئة.
  static final Map<String, ComponentRegistryEntry> _registry = {};

  static void registerEntry(ComponentRegistryEntry entry) {
    _registry[entry.componentType] = entry;
  }

  static void clearEntries() => _registry.clear();
}
