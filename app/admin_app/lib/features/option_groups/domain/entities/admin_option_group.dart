import 'package:admin_app/core/locale/app_locale.dart';

/// النطاق الذي تسري عليه مجموعة الخيارات، وهو عمود `applies_to` في 224.
///
/// المجموعة إما لكل المنتجات، أو لفئات محددة، أو لمنتجات محددة؛ والحلّ في
/// القاعدة هو `catalog.effective_product_option_groups` وحده يقرر مَن يراها
/// العميل، فاللوحة تعرض نفس الجواب لا أكثر.
enum AdminOptionGroupScope {
  all('all'),
  category('category'),
  products('products');

  const AdminOptionGroupScope(this.key);

  /// القيمة كما تُخزَّن في العمود.
  final String key;

  static AdminOptionGroupScope fromKey(String? key) {
    return AdminOptionGroupScope.values.firstWhere(
      (scope) => scope.key == key,
      orElse: () => AdminOptionGroupScope.products,
    );
  }
}

/// نوع الاختيار داخل المجموعة: حجم واحد لا غير، أو إضافات متعددة.
enum AdminOptionSelectionType {
  single('single'),
  multiple('multiple');

  const AdminOptionSelectionType(this.key);

  final String key;

  static AdminOptionSelectionType fromKey(String? key) {
    return AdminOptionSelectionType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => AdminOptionSelectionType.single,
    );
  }
}

/// One selectable value of a group: a size, a sugar level or an extra.
class AdminOptionValue {
  const AdminOptionValue({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.id = '',
    this.priceDelta = 0,
    this.sortOrder = 0,
    this.isDefault = false,
    this.isActive = true,
  });

  /// فارغ حتى تُحفظ القيمة، فمعرّفها من القاعدة لا من اللوحة.
  final String id;
  final String code;
  final String nameAr;
  final String nameEn;

  /// الفارق الذي يُضاف إلى سعر المنتج، لا سعر مطلق: المنتج أساسه ١٠ والحجم
  /// الكبير +٣ فيصبح المعروض ١٣، وهو ما يقرأه `resolve_effective_price`.
  final double priceDelta;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;

  String nameFor(AppLanguage language) => language.isArabic ? nameAr : nameEn;

  AdminOptionValue copyWith({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    double? priceDelta,
    int? sortOrder,
    bool? isDefault,
    bool? isActive,
  }) {
    return AdminOptionValue(
      id: id ?? this.id,
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      priceDelta: priceDelta ?? this.priceDelta,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }

  factory AdminOptionValue.fromJson(Map<String, dynamic> json) {
    return AdminOptionValue(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      priceDelta: (json['price_delta'] as num?)?.toDouble() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] == true,
      isActive: json['is_active'] != false,
    );
  }

  /// السطر كما تكتبه القاعدة؛ `group_id` يضيفه المستودع وحده.
  Map<String, dynamic> toRow() => <String, dynamic>{
    'code': code,
    'name_ar': nameAr,
    'name_en': nameEn.isEmpty ? nameAr : nameEn,
    'price_delta': priceDelta,
    'sort_order': sortOrder,
    'is_default': isDefault,
    'is_active': isActive,
  };
}

/// An option group as the dashboard edits it: sizes, sugar or extras.
class AdminOptionGroup {
  const AdminOptionGroup({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.id = '',
    this.selectionType = AdminOptionSelectionType.single,
    this.minSelect = 0,
    this.maxSelect,
    this.isRequired = false,
    this.sortOrder = 0,
    this.isActive = true,
    this.scope = AdminOptionGroupScope.products,
    this.categoryIds = const <String>[],
    this.productIds = const <String>[],
    this.excludedProductIds = const <String>[],
    this.values = const <AdminOptionValue>[],
  });

  final String id;

  /// `^[a-z_]+$` كما يشترطه العمود في 008.
  final String code;
  final String nameAr;
  final String nameEn;
  final AdminOptionSelectionType selectionType;
  final int minSelect;

  /// null تعني بلا سقف، ولا تُترك إلا في مجموعة الاختيارات المتعددة.
  final int? maxSelect;
  final bool isRequired;
  final int sortOrder;
  final bool isActive;

  final AdminOptionGroupScope scope;

  /// الفئات حين يكون النطاق `category`.
  final List<String> categoryIds;

  /// المنتجات حين يكون النطاق `products`.
  final List<String> productIds;

  /// منتجات مُستثناة، وتحمل صفّ الربط بـ `is_excluded = true`.
  final List<String> excludedProductIds;

  final List<AdminOptionValue> values;

  String nameFor(AppLanguage language) => language.isArabic ? nameAr : nameEn;

  /// عدد المنتجات التي ستظهر لها المجموعة كما تقرر ذلك صلاحيات اللوحة نفسها.
  ///
  /// النطاق العام لا سقف له عند الفئة، فالرقم هنا وصفي فقط ويترك العدد الفعلي
  /// للقاعدة التي تحلّ النطاق.
  bool get isUniversal => scope == AdminOptionGroupScope.all;

  AdminOptionGroup copyWith({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    AdminOptionSelectionType? selectionType,
    int? minSelect,
    int? maxSelect,
    bool clearMaxSelect = false,
    bool? isRequired,
    int? sortOrder,
    bool? isActive,
    AdminOptionGroupScope? scope,
    List<String>? categoryIds,
    List<String>? productIds,
    List<String>? excludedProductIds,
    List<AdminOptionValue>? values,
  }) {
    return AdminOptionGroup(
      id: id ?? this.id,
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      selectionType: selectionType ?? this.selectionType,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: clearMaxSelect ? null : (maxSelect ?? this.maxSelect),
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      scope: scope ?? this.scope,
      categoryIds: categoryIds ?? this.categoryIds,
      productIds: productIds ?? this.productIds,
      excludedProductIds: excludedProductIds ?? this.excludedProductIds,
      values: values ?? this.values,
    );
  }

  factory AdminOptionGroup.fromJson(Map<String, dynamic> json) {
    return AdminOptionGroup(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      selectionType: AdminOptionSelectionType.fromKey(
        json['selection_type'] as String?,
      ),
      minSelect: (json['min_select'] as num?)?.toInt() ?? 0,
      maxSelect: (json['max_select'] as num?)?.toInt(),
      isRequired: json['is_required'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      scope: AdminOptionGroupScope.fromKey(json['applies_to'] as String?),
    );
  }

  /// صفّ المجموعة وحده: النطاق والقيم تكتبهما جداول أخرى، ودالة الحلّ في 224
  /// تقرأهما معًا.
  Map<String, dynamic> toRow() => <String, dynamic>{
    'code': code,
    'name_ar': nameAr,
    'name_en': nameEn.isEmpty ? nameAr : nameEn,
    'selection_type': selectionType.key,
    'min_select': minSelect,
    'max_select': maxSelect,
    'is_required': isRequired,
    'sort_order': sortOrder,
    'is_active': isActive,
    'applies_to': scope.key,
  };
}
