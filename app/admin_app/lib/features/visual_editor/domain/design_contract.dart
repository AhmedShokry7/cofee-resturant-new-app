/// عقد مستند التصميم بين محرّر الأدمن وقارئ تطبيق العميل.
///
/// الحزمتان لا تستورد إحداهما الأخرى: المفاتيح نفسها مكتوبة هنا وفي
/// `lib/features/design/data/model/published_design.dart` لدى تطبيق العميل،
/// وحرس التطابق (`test/design_theme_contract_parity_test.dart` هناك) يقرأ
/// النصّ من الملفين ويمنع انزياح أي مفتاح في طرف دون الآخر.
///
/// هذه القوائم ليست اختيارية: `core.app_design_is_valid` (migrations 226/227)
/// ترفض النشر بأي مفتاح خارجها، فالمصدر الأول للعقد قاعدة البيانات، ويلتزم
/// بها المحرّر وقارئ الهاتف.
library;

/// أدوار الألوان في طبقة `theme` — نفس مفاتيح `ThemeColorRole` لدى العميل.
enum DesignColorRole {
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

  const DesignColorRole(this.key);

  final String key;
}

/// عقود المستند: صفحات ومكونات ومصادر بيانات، بمفاتيح المنشور.
abstract final class DesignContract {
  DesignContract._();

  /// مفاتيح الصفحات التي تقبلها `app_design_is_valid` (226).
  static const List<String> pageKeys = [
    'home',
    'categories',
    'search',
    'product_details',
    'cart',
    'favourites',
    'settings',
  ];

  /// أنواع العقد التي يرسمها الهاتف (DesignWidgetTypes لدى العميل).
  static const String pageHome = 'page.home';
  static const String header = 'section.header';
  static const String searchBar = 'section.search_bar';
  static const String bannerCarousel = 'section.banner_carousel';
  static const String categoryList = 'section.category_list';
  static const String promoBanner = 'section.promo_banner';
  static const String productStrip = 'section.product_strip';
  static const String bundleList = 'section.bundle_list';

  /// أنواع الأقسام التي يرسمها الهاتف. القيم نصّية عمدًا: النصّ المكتوب
  /// هو العقدة التي يقرؤها حرس التطابق من هذا الملف لا من الاستيراد.
  static const List<String> sectionTypes = [
    'section.header',
    'section.search_bar',
    'section.banner_carousel',
    'section.category_list',
    'section.promo_banner',
    'section.product_strip',
    'section.bundle_list',
    'section.text',
    'section.heading',
    'section.button',
    'section.image',
    'section.divider',
    'section.spacer',
    'section.product_grid',
    'section.column',
  ];

  /// مصادر البيانات المميزة للأقسام المتشابهة (DesignDataSources لدى العميل).
  static const String featured = 'catalog.featured';
  static const String recommendations = 'catalog.recommendations';

  /// أنواع المحتوى الحر والهياكل، بمفاتيح العقد كما يرسمها الهاتف.
  static const String text = 'section.text';
  static const String heading = 'section.heading';
  static const String button = 'section.button';
  static const String image = 'section.image';
  static const String divider = 'section.divider';
  static const String spacer = 'section.spacer';
  static const String productGrid = 'section.product_grid';
  static const String column = 'section.column';

  /// أسماء مقاييس النص التي تعيدها `app_design_is_valid`.
  static const List<String> textScales = [
    'default',
    'compact',
    'comfortable',
    'large',
  ];

  /// أسماء مقاييس التقويس التي تعيدها `app_design_is_valid`.
  static const List<String> radiusScales = [
    'default',
    'sharp',
    'soft',
    'round',
    'pill',
  ];

  /// مضاعفات الخط: الأرقام نفسها في `_textFactors` لدى العميل.
  static const Map<String, double> textFactors = <String, double>{
    'default': 1,
    'compact': 0.9,
    'comfortable': 1.05,
    'large': 1.15,
  };

  /// رقم المخطط الذي يقرؤه الهاتف ويعيده المدقق الحي.
  static const int readableSchemaVersion = 2;
}

/// طبقة الشكل كما تحملها وثيقة الأدمن داخل `theme`.
///
/// دور غائب يعني «دع ما عند الزبون كما هو» — قارئ العميل يجيب عن الغائب
/// بأصل اللون، فلا طبقة فارغة تعني لا تدخل في الشكل.
class DesignTheme {
  const DesignTheme({
    this.colors = const <DesignColorRole, String>{},
    this.textScale,
    this.radiusScale,
  });

  /// طبقة محايدة: لا لون ولا مقياس. تُسلسل إلى مستند بلا `theme` على الإطلاق.
  static const DesignTheme none = DesignTheme();

  /// الأدوار المكتوبة، قيمها `#RRGGBB` أو `#AARRGGBB` كما تُدقق في SQL.
  final Map<DesignColorRole, String> colors;

  /// اسم المقياس من [DesignContract.textScales]، أو null لأصله.
  final String? textScale;

  /// اسم المقياس من [DesignContract.radiusScales]، أو null لأصله.
  final String? radiusScale;

  bool get isEmpty =>
      colors.isEmpty && textScale == null && radiusScale == null;

  /// كما ستقرأها القاعدة والهاتف. طبقة محايدة تُسلسل إلى null لا إلى `{}` —
  /// الفارغ غيابٌ لا طبقة، والمدقق الحي يقبل الغياب لا الطبقة الهشة.
  Map<String, dynamic>? toJson() {
    if (isEmpty) return null;
    return {
      if (colors.isNotEmpty)
        'colors': {
          for (final entry in colors.entries) entry.key.key: entry.value,
        },
      if (textScale != null) 'text_scale': textScale,
      if (radiusScale != null) 'radius_scale': radiusScale,
    };
  }

  /// قراءة متسامحة: مفتاح مجهول أو قيمة ليست لونًا تُسقط دورها ولا تُهجر
  /// الطبقة. مطابق لسلوك `PublishedTheme.fromJson` لدى العميل.
  static DesignTheme fromJson(Object? raw) {
    if (raw is! Map) return none;
    final colors = <DesignColorRole, String>{};
    final rawColors = raw['colors'];
    if (rawColors is Map) {
      for (final entry in rawColors.entries) {
        final role = _roleOfKey(entry.key);
        if (role != null && entry.value is String) {
          colors[role] = entry.value as String;
        }
      }
    }
    final scale = raw['text_scale'];
    final radius = raw['radius_scale'];
    return DesignTheme(
      colors: colors,
      textScale: scale is String ? scale : null,
      radiusScale: radius is String ? radius : null,
    );
  }

  static DesignColorRole? _roleOfKey(Object? key) {
    for (final role in DesignColorRole.values) {
      if (role.key == key) return role;
    }
    return null;
  }
}
