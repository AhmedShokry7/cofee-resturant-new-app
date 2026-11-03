import 'package:admin_app/features/customer_preview/domain/registry/design_property.dart';

/// ما يرجعه مصدر البيانات، وهو الذي يقرّر أي مكوّن يقبله ابنًا.
enum DesignDataShape { products, banners, categories, bundles }

/// مصدر بيانات حقيقي واحد يستطيع مكوّن أن يتغذّى عليه.
///
/// المصادر هنا ليست زينة: كل مفتاح له طريق قراءة قائم فعلًا في عقود
/// صفحات الإدارة (الكتالوج والبنرات والباقات والتصنيفات وشريط القاعدة)، ولا
/// مصدر يُوعد ببيانات لا تملك اللوحة قراءة لها.
class DataSourceSpec {
  const DataSourceSpec({
    required this.key,
    required this.name,
    required this.description,
    required this.shape,
    this.needsParameter,
  });

  final String key;
  final L10nText name;
  final L10nText description;
  final DesignDataShape shape;

  /// اسم الخاصية التي يحمل المكوّن بها معرّف العنصر المطلوب، مثل تصنيف.
  final String? needsParameter;
}

/// سجل مصادر البيانات التي يعرضها المحرّر.
abstract final class DataSourceRegistry {
  DataSourceRegistry._();

  static const String products = 'catalog.products';
  static const String featured = 'catalog.featured';
  static const String recommendations = 'catalog.recommendations';
  static const String categoryProducts = 'catalog.in_category';
  static const String searchResults = 'catalog.search_results';
  static const String banners = 'marketing.banners';
  static const String bundles = 'catalog.bundles';
  static const String categories = 'catalog.categories';

  static const List<DataSourceSpec> specs = <DataSourceSpec>[
    DataSourceSpec(
      key: products,
      name: L10nText('كل المنتجات', 'All products'),
      description: L10nText(
        'ما يرجعه صف الكتالوج للفرع المختار، بصفحة بمقاس صفحة المنتجات في اللوحة.',
        'The catalog page for the selected branch, same size as the products page.',
      ),
      shape: DesignDataShape.products,
    ),
    DataSourceSpec(
      key: featured,
      name: L10nText('الأكثر طلبًا', 'Featured'),
      description: L10nText(
        'شريط القاعدة نفسه: مثبّت يدويًا ثم أكثر مبيعًا، وبأسعارها المحسوبة.',
        'The same row the database builds: pinned rows then best sellers.',
      ),
      shape: DesignDataShape.products,
    ),
    DataSourceSpec(
      key: recommendations,
      name: L10nText('ترشيحات لك', 'Recommended for you'),
      description: L10nText(
        'ترتيب العميل: حرارة الفرع أوّلًا، ثم ما لم يعرضه الشريط.',
        'The customer rule: branch weather first, then what the row did not show.',
      ),
      shape: DesignDataShape.products,
    ),
    DataSourceSpec(
      key: categoryProducts,
      name: L10nText('منتجات تصنيف', 'Products of a category'),
      description: L10nText(
        'منتجات تصنيف مختار من التصنيفات النشطة، بنفس قواعد البيع والسعر.',
        'Products of a chosen active category, with the same sellable and price rules.',
      ),
      shape: DesignDataShape.products,
      needsParameter: 'categoryId',
    ),
    DataSourceSpec(
      key: searchResults,
      name: L10nText('نتائج البحث', 'Search results'),
      description: L10nText(
        'ما يطابق ما كتبه الموظف في حقل البحث، بقاعدة بحث العميل نفسها. بلا '
            'كتابة يرجع فارغًا كما ترجع صفحة البحث عند الزبون.',
        'Rows matching what the staff typed, on the customer search rule. With no '
            'query it is empty, like the customer search page.',
      ),
      shape: DesignDataShape.products,
    ),
    DataSourceSpec(
      key: banners,
      name: L10nText('البنرات المنشورة', 'Published banners'),
      description: L10nText(
        'بنرات في وقتها ومرتبّة بترتيبها المحفوظ، وهي ما يراه الزبون.',
        'Banners inside their window, in their stored order, as the customer sees them.',
      ),
      shape: DesignDataShape.banners,
    ),
    DataSourceSpec(
      key: bundles,
      name: L10nText('الباقات النشطة', 'Active bundles'),
      description: L10nText(
        'باقات اللوحة نفسها بمكوّناتها وسعرها والمجموع الأصلي قبل الخصم.',
        'The dashboard bundles with their components, price and original total.',
      ),
      shape: DesignDataShape.bundles,
    ),
    DataSourceSpec(
      key: categories,
      name: L10nText('التصنيفات النشطة', 'Active categories'),
      description: L10nText(
        'التصنيفات كما ترسلها القاعدة إلى شاشة الزبون، بلا الموقوف منها.',
        'Categories as the database sends them to the customer, inactive ones excluded.',
      ),
      shape: DesignDataShape.categories,
    ),
  ];

  static final Map<String, DataSourceSpec> _byKey = <String, DataSourceSpec>{
    for (final spec in specs) spec.key: spec,
  };

  static DataSourceSpec? of(String? key) => key == null ? null : _byKey[key];

  static bool knows(String key) => _byKey.containsKey(key);
}
