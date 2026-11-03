import 'package:admin_app/features/customer_preview/domain/registry/design_property.dart';

/// ما يفعله الإجراء عند العميل، وهو قائمة محدودة لا نص حر في المستند.
enum DesignActionTarget {
  /// لا شيء: المكوّن للعرض وحده.
  none,

  /// الانتقال إلى صفحة من سجل الصفحات.
  page,

  /// فتح تصنيف بشاشته.
  category,

  /// فتح صفحة تفاصيل منتج.
  product,

  /// فتح صفحة «عرض الكل» لمصدر المقطع، وهي `seeAllProductsRoute` عند العميل.
  seeAll,

  /// فتح البحث مع كلمة جاهزة أو بلا كلمة.
  search,
}

/// إجراء واحد مسجَّل يستطيع الموظف اختياره.
///
/// لا نص Dart ولا SQL ولا JavaScript في المستند: الاختيار من هذه القائمة وحدها،
/// وكل مفتاح له تنفيذ في `DesignRenderer` أو لا يُعرض.
class ActionSpec {
  const ActionSpec({
    required this.key,
    required this.name,
    required this.target,
    this.needsParameter,
    this.description,
  });

  final String key;
  final L10nText name;
  final DesignActionTarget target;

  /// الخاصة التي يحمل المكوّن بها المعرّف المطلوب (تصنيف أو منتج أو صفحة).
  final String? needsParameter;

  final L10nText? description;
}

/// سجل الإجراءات الذي يحدّد ما يملك المحرّر ربطه بالمكوّنات.
abstract final class ActionRegistry {
  ActionRegistry._();

  static const String none = 'none';
  static const String navigateHome = 'navigate.home';
  static const String navigateCategories = 'navigate.categories';
  static const String navigateSearch = 'navigate.search';
  static const String navigateCart = 'navigate.cart';
  static const String navigateFavourites = 'navigate.favourites';
  static const String navigateSettings = 'navigate.settings';
  static const String openCategory = 'open.category';
  static const String openProduct = 'open.product';
  static const String seeAllProducts = 'open.see_all_products';

  static const List<ActionSpec> specs = <ActionSpec>[
    ActionSpec(
      key: none,
      name: L10nText('بلا إجراء', 'No action'),
      target: DesignActionTarget.none,
      description: L10nText(
        'للعرض فقط، فلا وعد بضغط لا ينفّذ شيء.',
        'Display only.',
      ),
    ),
    ActionSpec(
      key: navigateHome,
      name: L10nText('الرئيسية', 'Go to home'),
      target: DesignActionTarget.page,
      needsParameter: 'page',
    ),
    ActionSpec(
      key: navigateCategories,
      name: L10nText('التصنيفات', 'Go to categories'),
      target: DesignActionTarget.page,
      needsParameter: 'page',
    ),
    ActionSpec(
      key: navigateSearch,
      name: L10nText('البحث', 'Open search'),
      target: DesignActionTarget.page,
      needsParameter: 'page',
    ),
    ActionSpec(
      key: navigateCart,
      name: L10nText('السلة', 'Open cart'),
      target: DesignActionTarget.page,
      needsParameter: 'page',
    ),
    ActionSpec(
      key: navigateFavourites,
      name: L10nText('المفضلة', 'Open favourites'),
      target: DesignActionTarget.page,
      needsParameter: 'page',
    ),
    ActionSpec(
      key: navigateSettings,
      name: L10nText('حسابي', 'Open account'),
      target: DesignActionTarget.page,
      needsParameter: 'page',
    ),
    ActionSpec(
      key: openCategory,
      name: L10nText('فتح تصنيف', 'Open a category'),
      target: DesignActionTarget.category,
      needsParameter: 'categoryId',
    ),
    ActionSpec(
      key: openProduct,
      name: L10nText('فتح منتج', 'Open a product'),
      target: DesignActionTarget.product,
      needsParameter: 'productId',
    ),
    ActionSpec(
      key: seeAllProducts,
      name: L10nText('عرض الكل', 'See all'),
      target: DesignActionTarget.seeAll,
      needsParameter: 'dataSource',
      description: L10nText(
        'صفحة قائمة على مصدر المقطع نفسه، وهي موجودة عند العميل اليوم.',
        'A list page over the section’s own source, as the customer app already has it.',
      ),
    ),
  ];

  static final Map<String, ActionSpec> _byKey = <String, ActionSpec>{
    for (final spec in specs) spec.key: spec,
  };

  static ActionSpec? of(String? key) => key == null ? null : _byKey[key];

  static bool knows(String key) => _byKey.containsKey(key);

  /// ما يملك زرّ ثابت أن يفعله: وجهة معروفة سلفًا، بلا صف تُقرأ هويته منه.
  static const List<String> destinations = <String>[
    none,
    navigateHome,
    navigateCategories,
    navigateSearch,
    navigateCart,
    navigateFavourites,
    navigateSettings,
  ];

  /// ما يملك زرّ أن يفتحه بشيء محدد في الإعدادات، لا في وقت الضغط.
  static const List<String> references = <String>[openCategory, openProduct];

  /// قائمة المفاتيح المسموحة لمكوّن، بترتيب العرض في اللوحة.
  static List<String> keysOf(Iterable<String> keys) =>
      keys.where(knows).toList();
}
