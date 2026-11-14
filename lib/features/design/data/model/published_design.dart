import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// أدوار الألوان التي يملكها مستند التصميم المنشور.
///
/// المفاتيح عقد مع لوحة الأدمن ومنشور القاعدة: ما يُطبع في `theme.colors` هو
/// `key` هنا بالحرف. الاختلاف أن القارئ هنا لا يعرف أسماء مقروءة — اللوحة وحدها
/// تسمّي، فالزبون لا يرى قائمة أدوار.
enum ThemeColorRole {
  primary('primary'),
  secondary('secondary'),
  background('background'),
  surface('surface'),
  textPrimary('text_primary'),
  textSecondary('text_secondary'),
  border('border'),
  success('success'),
  error('error'),
  disabled('disabled');

  const ThemeColorRole(this.key);

  final String key;

  static ThemeColorRole? ofKey(String? key) {
    for (final role in ThemeColorRole.values) {
      if (role.key == key) return role;
    }
    return null;
  }
}

/// طبقة الشكل كما نشرها الموظف، فوققة لا تصميم كامل.
///
/// الدور الغائب يعني «دع ما عند الزبون كما هو»: لا أسود ولا رمادي من عند القارئ.
/// كذلك تُقرأ طبقة فارغة على أنها لا طبقة، فيبقى الرسم يومَ النشر مطابقًا لرسم
/// اليوم حرفيًا.
class PublishedTheme {
  const PublishedTheme({
    this.colors = const <ThemeColorRole, Color>{},
    this.textFactor = 1,
  });

  static const PublishedTheme none = PublishedTheme();

  final Map<ThemeColorRole, Color> colors;

  /// مضاعف الخط: `default` وقيمته 1، فالنشر الذي لم يلمس المقياس لا يُكبّر حرفًا.
  final double textFactor;

  bool get isNeutral => colors.isEmpty && textFactor == 1;

  /// طبقة كما ستُقرأ مجددًا: عقد واحد في كلا الاتجاهين. تستعمل للإرسال
  /// الراجع إلى محرّر الأدمن (COMPONENT_TREE_UPDATED) لا للحفظ.
  Map<String, dynamic> toJson() => {
    if (colors.isNotEmpty)
      'colors': {
        for (final entry in colors.entries)
          entry.key.key: _hex(entry.value),
      },
    if (textFactor != 1) 'text_scale': _scaleName(textFactor),
  };

  static String _hex(Color color) {
    final value = color.toARGB32();
    final rgb = value & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// الاسم كما هو في [_textFactors]؛ غير موجود يعني طبقة من مصدر آخر —
  /// تُرسل بدون مقياس لا باسم مختلق.
  static String? _scaleName(double factor) {
    for (final entry in _textFactors.entries) {
      if (entry.value == factor) return entry.key;
    }
    return null;
  }

  Color? color(ThemeColorRole role) => colors[role];

  /// تساوي بالمحتوى: إعادة قراءة أعطت الطبقة نفسها لا تُعيد بناء الشاشة كلها.
  @override
  bool operator ==(Object other) =>
      other is PublishedTheme &&
      other.textFactor == textFactor &&
      _sameColors(other.colors);

  @override
  int get hashCode => Object.hash(textFactor, Object.hashAll(colors.entries));

  bool _sameColors(Map<ThemeColorRole, Color> other) {
    if (other.length != colors.length) return false;
    for (final entry in colors.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// قراءة متسامحة عمدًا.
  ///
  /// القاعدة ترفض المستند غير الصالح قبل النشر، لكن الصف قد يُكتب من مصدر آخر أو
  /// يُقرأ بعد ترقية لم يعرفها هذا التطبيق. هنا الثمن شاشة زبون: سطر لا يُفهم
  /// يترك الألوان كما كانت، ولا يترك صفحة بيضاء. المفتاح المجهول والقيمة غير
  /// اللون يُتجاهلان دورًا دورًا، ولا يُهجر المستند كله لأجلهما.
  static PublishedTheme fromJson(Object? raw) {
    if (raw is! Map) return none;
    final colors = <ThemeColorRole, Color>{};
    final rawColors = raw['colors'];
    if (rawColors is Map) {
      for (final entry in rawColors.entries) {
        final role = ThemeColorRole.ofKey(entry.key);
        final color = _color(entry.value);
        if (role != null && color != null) colors[role] = color;
      }
    }
    final scale = raw['text_scale'];
    final factor = scale is String ? _textFactors[scale] : null;
    if (colors.isEmpty && factor == null) return none;
    return PublishedTheme(
      colors: colors,
      textFactor: factor ?? 1,
    );
  }

  /// مضاعفات الخط: الأرقام نفسها في سجل الأدمن، فاسم المقياس عقد بين الطرفين لا
  /// ذكرى في أحدهما، وحرس التطابق في الاختبارات يربطهما.
  static const Map<String, double> _textFactors = <String, double>{
    'default': 1,
    'compact': 0.9,
    'comfortable': 1.05,
    'large': 1.15,
  };

  /// `#RRGGBB` أو `#AARRGGBB`، أو null لغيرهما. الشفافية تُحترم لأنها في العقد،
  /// بخلاف معاينة الرابط التي تُجبر اللون معتمًا لأن غياب الشفافية هناك اختيار
  /// للمعاينة لا قرار منشور.
  static Color? _color(Object? raw) {
    if (raw is! String) return null;
    final hex = raw.startsWith('#') ? raw.substring(1) : raw;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return hex.length == 8 ? Color(value) : Color(0xFF000000 | value);
  }
}

/// أنواع العقد التي يعرفها الهاتف، بمفاتيحها في المستند.
///
/// النصوص عقد مع سجل مكوّنات اللوحة (`WidgetTypes`) وحرس التطابق في
/// `design_theme_contract_parity_test.dart` يربطهما: نوع تنشره اللوحة ولا يسمّيه
/// الهاتف قسمٌ لا يُرسم، لا شاشة ناقصة يلاحظها أحد.
abstract final class DesignWidgetTypes {
  DesignWidgetTypes._();

  static const String pageHome = 'page.home';
  static const String header = 'section.header';
  static const String searchBar = 'section.search_bar';
  static const String bannerCarousel = 'section.banner_carousel';
  static const String promoBanner = 'section.promo_banner';
  static const String categoryList = 'section.category_list';
  static const String productStrip = 'section.product_strip';
  static const String bundleList = 'section.bundle_list';

  /// أنواع المحتوى الحر والهياكل — عقد واحد مع لوحة الأدمن، وحرس التطابق
  /// في `design_theme_contract_parity_test.dart` يمنع انزياح مفتاح في
  /// طرف دون الآخر.
  static const String text = 'section.text';
  static const String heading = 'section.heading';
  static const String button = 'section.button';
  static const String image = 'section.image';
  static const String divider = 'section.divider';
  static const String spacer = 'section.spacer';
  static const String productGrid = 'section.product_grid';
  static const String column = 'section.column';
}

/// مصدر البيانات الذي يميّز عقدة عن أختها بالنوع نفسه.
///
/// شريطا «الأكثر طلبًا» و«ترشيحات لك» نوع واحد في المستند، والفصل كله هنا — كما
/// في اللوحة، وكما في حرس التطابق الذي يمنع توحيدهما سهوًا.
abstract final class DesignDataSources {
  DesignDataSources._();

  static const String featured = 'catalog.featured';
  static const String recommendations = 'catalog.recommendations';
}

/// قسم على شاشة الزبون، كما خرج من المستند المنشور.
///
/// لا يُبنى منه widget هنا: الهاتف يعرف مكوّناته، وهذه الطبعة تحمل ما يقوله
/// المستند لا ما يرسمه.
class PublishedSection {
  const PublishedSection({
    required this.id,
    required this.type,
    this.visible = true,
    this.dataSource,
    this.properties = const <String, dynamic>{},
    this.children = const <PublishedSection>[],
  });

  final String id;
  final String type;

  /// `visible: false` يعني أن الموظف أخفى القسم؛ الغياب إخفاء لا حذف، لأن
  /// المحرّر يُظهره مرة أخرى بنفس المعرّف.
  final bool visible;

  /// قيمة خاصية `dataSource` إن كانت، لتفريق العقد المتساوية النوع.
  final String? dataSource;

  /// خصائص القسم كما خرجت من المستند: أعداد أولية فقط (نصّ/رقم/منطق) —
  /// المدقق الحي يرفض غيرها قبل النشر، والقارئ المتسامح يسقط ما فات.
  final Map<String, dynamic> properties;

  /// أبناء القسم (أبناء عمود مثلًا) بترتيبهم المنشور؛ فارغ لما لا يحمل
  /// أبناء. القراءة متكررة، فعمود داخل عمود يعمل بلا شكل خاص.
  final List<PublishedSection> children;

  /// خاصية نصّية، أو null لغيابها أو غيرها.
  String? property(String key) {
    final value = properties[key];
    return value is String ? value : null;
  }

  /// خاصية رقمية، أو null. الأدمن يخزّن أحجام الخط نصوصًا ('14')، فالقارئ
  /// يقبلها كرقم إن قُبل تحليلها.
  double? numberProperty(String key) {
    final value = properties[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// خاصية منطقية مع افتراضي.
  bool flagProperty(String key, {bool fallback = false}) {
    final value = properties[key];
    return value is bool ? value : fallback;
  }

  /// تساوي بالمحتوى: قارئان للمستند نفسه يعطيان القسم نفسه، فلا تُعاد بناء
  /// الشاشة لقراءة لم تغيّر حرفًا.
  @override
  bool operator ==(Object other) =>
      other is PublishedSection &&
      other.id == id &&
      other.type == type &&
      other.visible == visible &&
      other.dataSource == dataSource &&
      mapEquals(other.properties, properties) &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    visible,
    dataSource,
    Object.hashAll(
      properties.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(children),
  );

  /// عقدة بلا معرّف أو بلا نوع ليست قسمًا: تُتجاهل وحدها ولا يُهجر المستند،
  /// كما تُتجاهل الألوان التالفة.
  static PublishedSection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final type = raw['type'];
    if (id is! String || id.isEmpty) return null;
    if (type is! String || type.isEmpty) return null;
    final properties = <String, dynamic>{};
    final rawProperties = raw['properties'];
    if (rawProperties is Map) {
      // أعداد أولية فقط، كما تشترط `app_design_node_check`: قيمة كائن
      // أو مصفوفة لا تصل إلى الهاتف أصلًا، فتجاهلها دورًا دورًا.
      rawProperties.forEach((key, value) {
        if (key is String &&
            (value is String || value is num || value is bool)) {
          properties[key] = value;
        }
      });
    }
    final source = properties['dataSource'];
    final children = <PublishedSection>[
      if (raw['children'] is List)
        for (final child in raw['children'] as List)
          if (PublishedSection.fromJson(child) case PublishedSection section)
            section,
    ];
    return PublishedSection(
      id: id,
      type: type,
      visible: raw['visible'] is bool ? raw['visible']! as bool : true,
      dataSource: source is String ? source : null,
      properties: properties,
      children: children,
    );
  }
}

/// المستند المنشور كما يقرؤه الزبون: الرقم الذي يُقرأ به، وطبقة شكله، وأقسامه.
///
/// رقم المخطط يعطّل القراءة لصدر لا يعرفه هذا التطبيق: طبقة من نسخة أحدث قد
/// تحمل أدوارًا غير هذه، والأصل أن يرسم الزبون ما يعرف لا ما يخمّن.
class PublishedDesign {
  const PublishedDesign({
    this.schemaVersion = 0,
    this.theme = PublishedTheme.none,
    this.homeSections = const <PublishedSection>[],
  });

  /// لا مستند: لا رقم مخطط ولا طبقة ولا أقسام، ترسم الشاشة كما كانت اليوم.
  static const PublishedDesign none = PublishedDesign();

  final int schemaVersion;
  final PublishedTheme theme;

  /// أقسام الصفحة الرئيسية بترتيبها المنشور، وخاليًا حين لا صفحة رئيسية في
  /// المستند — عندئذ يرسم الهاتف ترتيبه المكتوب في مصدره.
  final List<PublishedSection> homeSections;

  /// المستند كما يقرؤه هذا التطبيق مرة أخرى، بصيغة المنشور نفسها.
  ///
  /// يعيد صفحة `page.home` فقط: الهاتف يرسم هذه وحدها، وما في المستند الأصلي
  /// من صفحات أخرى مسؤولية اللوحة لا القارئ. تستعمل للإرسال الراجع إلى
  /// محرّر الأدمن (COMPONENT_TREE_UPDATED)؛ القراءة من JSON تبقى [fromJson].
  Map<String, dynamic> toDocument() => {
    'schema_version': schemaVersion,
    'theme': theme.toJson(),
    'pages': <Map<String, dynamic>>[
      {
        'page': 'home',
        'root': {
          'type': DesignWidgetTypes.pageHome,
          'children': <Map<String, dynamic>>[
            for (final section in homeSections) _sectionJson(section),
          ],
        },
      },
    ],
  };

  /// قسم كما يُقرأ مجددًا: خصائصه الأولية كلها وأبناؤه، لا مصدر بياناته
  /// وحده — التسلسل الراجع إلى المحرّر يفقد جزءًا لو نسّي جزءًا.
  static Map<String, dynamic> _sectionJson(PublishedSection section) => {
    'id': section.id,
    'type': section.type,
    'visible': section.visible,
    'properties': Map<String, dynamic>.from(section.properties),
    if (section.children.isNotEmpty)
      'children': [
        for (final child in section.children) _sectionJson(child),
      ],
  };

  /// المستندات المنشورة التي يقرأها هذا التطبيق. 1 بلا طبقة شكل، و2 بها.
  static const int readableSchemaVersion = 2;

  /// تساوي بالمحتوى: طبعة أعادت اللوحة نشرها كما كانت لا تحرّك شاشة الزبون.
  @override
  bool operator ==(Object other) =>
      other is PublishedDesign &&
      other.schemaVersion == schemaVersion &&
      other.theme == theme &&
      listEquals(other.homeSections, homeSections);

  @override
  int get hashCode =>
      Object.hash(schemaVersion, theme, Object.hashAll(homeSections));

  /// null عند صف غير موجود، أو كائن غير مستند، أو مخطط أحدث من التطبيق.
  static PublishedDesign? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['schema_version'];
    if (version is! num || version < 1) return null;
    if (version > readableSchemaVersion) return null;
    return PublishedDesign(
      schemaVersion: version.round(),
      theme: PublishedTheme.fromJson(raw['theme']),
      homeSections: _homeSections(raw['pages']),
    );
  }

  /// جذر صفحة `page.home` وأبناؤه بترتيبهم؛ صفحة أخرى أو مستند بلا صفحات لا
  /// يغيّران شيئًا.
  static List<PublishedSection> _homeSections(Object? pages) {
    if (pages is! List) return const <PublishedSection>[];
    for (final page in pages) {
      if (page is! Map || page['page'] != 'home') continue;
      final root = page['root'];
      if (root is! Map || root['type'] != DesignWidgetTypes.pageHome) {
        continue;
      }
      final children = root['children'];
      if (children is! List) return const <PublishedSection>[];
      return <PublishedSection>[
        for (final child in children)
          if (PublishedSection.fromJson(child) case PublishedSection section)
            section,
      ];
    }
    return const <PublishedSection>[];
  }
}
