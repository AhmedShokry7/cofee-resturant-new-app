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
    'splash',
    'welcome',
    'onboarding',
    'auth',
    'sign_up',
    'forget_password',
    'reset_password',
    'phone_auth',
    'email_auth',
    'home',
    'categories',
    'search',
    'product_details',
    'cart',
    'favourites',
    'settings',
    'checkout',
    'shipping_addresses',
    'add_address',
    'payment_method',
    'add_card',
    'payment_success',
    'e_receipt',
    'coupon',
    'orders',
    'edit_profile',
    'saved_cards',
    'addresses',
    'address_form',
    'loyalty',
    'subscription_plans',
    'subscription_details',
    'cashier_subscription',
    'notifications',
    'notification_settings',
    'help',
    'privacy',
    'assistant_memory',
  ];

  /// حد الصفحات في المستند الواحد، كما يتحقق منه `app_design_is_valid`.
  static const int maxPages = 40;

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

    /// عقد الشاشات المدمجة: لا يرسمها محرك الأقسام الحرّة، بل تقرؤها
    /// مكوّنات الشاشة نفسها (published_design لدى العميل) — خاصية فارغة
    /// تعني «كما هو»، و`visible: false` تعني إخفاء المكوّن الأصلي.
    'welcome.hero',
    'welcome.title',
    'welcome.body',
    'welcome.spacing',
    'onboarding.slide',
    'onboarding.transition',
    'auth.title',
    'auth.subtitle',
    'auth.social',
    'auth.switch_prompt',
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

  /// عقد الشاشات المدمجة، بمفاتيح العقد كما تقرؤها شاشات العميل
  /// (DesignWidgetTypes لدى العميل). خاصية فارغة تعني «كما هو»، و
  /// `visible: false` تعني إخفاء المكوّن الأصلي.
  static const String welcomeHero = 'welcome.hero';
  static const String welcomeTitle = 'welcome.title';
  static const String welcomeBody = 'welcome.body';
  static const String welcomeSpacing = 'welcome.spacing';
  static const String onboardingSlide = 'onboarding.slide';
  static const String onboardingTransition = 'onboarding.transition';
  static const String authTitle = 'auth.title';
  static const String authSubtitle = 'auth.subtitle';
  static const String authSocial = 'auth.social';
  static const String authSwitchPrompt = 'auth.switch_prompt';

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
    this.appNameAr,
    this.appNameEn,
    this.logoUrl,
  });

  /// طبقة محايدة: لا لون ولا مقياس ولا هوية. تُسلسل إلى مستند بلا `theme`
  /// على الإطلاق.
  static const DesignTheme none = DesignTheme();

  /// الأدوار المكتوبة، قيمها `#RRGGBB` أو `#AARRGGBB` كما تُدقق في SQL.
  final Map<DesignColorRole, String> colors;

  /// اسم المقياس من [DesignContract.textScales]، أو null لأصله.
  final String? textScale;

  /// اسم المقياس من [DesignContract.radiusScales]، أو null لأصله.
  final String? radiusScale;

  /// هوية التطبيق: الاسم بالعربي والإنجليزي، ورابط اللوجو. الفارغ يعني
  /// هوية التطبيق المضمّنة كما هي اليوم.
  final String? appNameAr;
  final String? appNameEn;
  final String? logoUrl;

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  bool get _hasBrand =>
      _nonEmpty(appNameAr) || _nonEmpty(appNameEn) || _nonEmpty(logoUrl);

  bool get isEmpty =>
      colors.isEmpty &&
      textScale == null &&
      radiusScale == null &&
      !_hasBrand;

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
      if (_hasBrand)
        'brand': {
          if (_nonEmpty(appNameAr)) 'name_ar': appNameAr!.trim(),
          if (_nonEmpty(appNameEn)) 'name_en': appNameEn!.trim(),
          if (_nonEmpty(logoUrl)) 'logo_url': logoUrl!.trim(),
        },
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
    final brand = raw['brand'] is Map ? raw['brand'] as Map : null;
    String? text(Object? value) => value is String && value.trim().isNotEmpty
        ? value.trim()
        : null;
    return DesignTheme(
      colors: colors,
      textScale: scale is String ? scale : null,
      radiusScale: radius is String ? radius : null,
      appNameAr: text(brand?['name_ar']),
      appNameEn: text(brand?['name_en']),
      logoUrl: text(brand?['logo_url']),
    );
  }

  static DesignColorRole? _roleOfKey(Object? key) {
    for (final role in DesignColorRole.values) {
      if (role.key == key) return role;
    }
    return null;
  }
}
