import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/pos/data/models/pos_json.dart';

/// How the cashier hands the order to the customer.
enum PosFulfillmentType {
  dineIn('dine_in'),
  pickup('pickup');

  const PosFulfillmentType(this.value);

  final String value;

  static PosFulfillmentType fromValue(Object? value) =>
      '$value'.trim().toLowerCase() == 'pickup'
      ? PosFulfillmentType.pickup
      : PosFulfillmentType.dineIn;

  bool get isDineIn => this == PosFulfillmentType.dineIn;
}

enum PosSelectionType {
  single('single'),
  multiple('multiple');

  const PosSelectionType(this.value);

  final String value;

  static PosSelectionType fromValue(Object? value) =>
      '$value'.trim().toLowerCase() == 'multiple'
      ? PosSelectionType.multiple
      : PosSelectionType.single;
}

class PosBranch {
  const PosBranch({
    required this.id,
    this.code = '',
    this.nameAr = '',
    this.nameEn = '',
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosBranch.fromJson(Map<String, dynamic> json) {
    return PosBranch(
      id: posText(json['id']),
      code: posText(json['code']),
      nameAr: posText(json['name_ar']),
      nameEn: posText(json['name_en']),
    );
  }
}

class PosCategory {
  const PosCategory({
    required this.id,
    this.nameAr = '',
    this.nameEn = '',
    this.imageUrl,
    this.sortOrder = 0,
    this.productCount = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String? imageUrl;
  final int sortOrder;
  final int productCount;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosCategory.fromJson(Map<String, dynamic> json) {
    return PosCategory(
      id: posText(json['id']),
      nameAr: posText(json['name_ar']),
      nameEn: posText(json['name_en']),
      imageUrl: posTextOrNull(json['image_url']),
      sortOrder: posInteger(json['sort_order']),
      productCount: posInteger(json['product_count']),
    );
  }
}

class PosPaymentMethod {
  const PosPaymentMethod({
    required this.id,
    this.code = '',
    this.nameAr = '',
    this.nameEn = '',
    this.isOnline = false,
    this.requiresSavedCard = false,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool isOnline;
  final bool requiresSavedCard;
  final int sortOrder;

  bool get isCash => code == 'cash';

  bool get isCard => code == 'card';

  /// The counter takes cash or card only; online wallets stay in the app.
  bool get isCounterTender => isCash || isCard;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosPaymentMethod.fromJson(Map<String, dynamic> json) {
    return PosPaymentMethod(
      id: posText(json['id']),
      code: posText(json['code']),
      nameAr: posText(json['name_ar']),
      nameEn: posText(json['name_en']),
      isOnline: posFlag(json['is_online']),
      requiresSavedCard: posFlag(json['requires_saved_card']),
      sortOrder: posInteger(json['sort_order']),
    );
  }
}

class PosOptionValue {
  const PosOptionValue({
    required this.id,
    this.nameAr = '',
    this.nameEn = '',
    this.priceDelta = 0,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final double priceDelta;
  final bool isDefault;
  final int sortOrder;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosOptionValue.fromJson(Map<String, dynamic> json) {
    return PosOptionValue(
      id: posText(json['id']),
      nameAr: posText(json['name_ar']),
      nameEn: posText(json['name_en']),
      priceDelta: posNumber(json['price_delta']),
      isDefault: posFlag(json['is_default']),
      sortOrder: posInteger(json['sort_order']),
    );
  }
}

class PosOptionGroup {
  const PosOptionGroup({
    required this.id,
    this.nameAr = '',
    this.nameEn = '',
    this.selectionType = PosSelectionType.single,
    this.minSelect = 0,
    this.maxSelect,
    this.isRequired = false,
    this.sortOrder = 0,
    this.values = const <PosOptionValue>[],
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final PosSelectionType selectionType;
  final int minSelect;
  final int? maxSelect;
  final bool isRequired;
  final int sortOrder;
  final List<PosOptionValue> values;

  bool get isSingle => selectionType == PosSelectionType.single;

  int get effectiveMin => isRequired && minSelect < 1 ? 1 : minSelect;

  int? get effectiveMax => isSingle ? 1 : maxSelect;

  /// The values a fresh dialog starts with: the defaults, or the first value
  /// when a required group has no default at all.
  List<PosOptionValue> get initialSelection {
    final defaults = [
      for (final value in values)
        if (value.isDefault) value,
    ];
    if (defaults.isNotEmpty) {
      final max = effectiveMax;
      return max == null || defaults.length <= max
          ? defaults
          : defaults.take(max).toList(growable: false);
    }
    if (isRequired && values.isNotEmpty) {
      return [values.first];
    }
    return const <PosOptionValue>[];
  }

  bool accepts(int selectedCount) {
    if (selectedCount < effectiveMin) return false;
    final max = effectiveMax;
    return max == null || selectedCount <= max;
  }

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosOptionGroup.fromJson(Map<String, dynamic> json) {
    return PosOptionGroup(
      id: posText(json['id']),
      nameAr: posText(json['name_ar']),
      nameEn: posText(json['name_en']),
      selectionType: PosSelectionType.fromValue(json['selection_type']),
      minSelect: posInteger(json['min_select']),
      maxSelect: posNullableInteger(json['max_select']),
      isRequired: posFlag(json['is_required']),
      sortOrder: posInteger(json['sort_order']),
      values: posMaps(json['values'])
          .map(PosOptionValue.fromJson)
          .toList(growable: false),
    );
  }
}

class PosProduct {
  const PosProduct({
    required this.id,
    this.categoryId = '',
    this.sku = '',
    this.slug = '',
    this.nameAr = '',
    this.nameEn = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.imageUrl,
    this.sortOrder = 0,
    this.isFeatured = false,
    this.prepMinutes,
    this.categoryNameAr = '',
    this.categoryNameEn = '',
    this.unitPrice = 0,
    this.regularPrice = 0,
    this.discountPercentage = 0,
    this.isAvailable = true,
    this.unavailableReason,
    this.stockQuantity = 0,
    this.trackStock = false,
    this.allowNegative = false,
    this.soldOut = false,
    this.optionGroups = const <PosOptionGroup>[],
  });

  final String id;
  final String categoryId;
  final String sku;
  final String slug;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String? imageUrl;
  final int sortOrder;
  final bool isFeatured;
  final int? prepMinutes;
  final String categoryNameAr;
  final String categoryNameEn;
  final double unitPrice;
  final double regularPrice;
  final double discountPercentage;
  final bool isAvailable;
  final String? unavailableReason;
  final int stockQuantity;
  final bool trackStock;
  final bool allowNegative;
  final bool soldOut;
  final List<PosOptionGroup> optionGroups;

  bool get hasOptions => optionGroups.isNotEmpty;

  bool get isSellable => isAvailable && !soldOut;

  bool get hasDiscount => discountPercentage > 0 || regularPrice > unitPrice;

  /// Null means the branch does not cap this product's quantity.
  int? get stockLimit {
    if (!trackStock || allowNegative) return null;
    return stockQuantity < 0 ? 0 : stockQuantity;
  }

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  String descriptionFor(AppLanguage language) {
    final primary = language.isArabic ? descriptionAr : descriptionEn;
    final fallback = language.isArabic ? descriptionEn : descriptionAr;
    final text = primary.trim();
    return text.isNotEmpty ? text : fallback.trim();
  }

  String categoryNameFor(AppLanguage language) {
    final primary = language.isArabic ? categoryNameAr : categoryNameEn;
    final fallback = language.isArabic ? categoryNameEn : categoryNameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return nameAr.toLowerCase().contains(normalized) ||
        nameEn.toLowerCase().contains(normalized) ||
        sku.toLowerCase().contains(normalized) ||
        categoryNameAr.toLowerCase().contains(normalized) ||
        categoryNameEn.toLowerCase().contains(normalized);
  }

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    return PosProduct(
      id: posText(json['id']),
      categoryId: posText(json['category_id']),
      sku: posText(json['sku']),
      slug: posText(json['slug']),
      nameAr: posText(json['name_ar']),
      nameEn: posText(json['name_en']),
      descriptionAr: posText(json['description_ar']),
      descriptionEn: posText(json['description_en']),
      imageUrl: posTextOrNull(json['image_url']),
      sortOrder: posInteger(json['sort_order']),
      isFeatured: posFlag(json['is_featured']),
      prepMinutes: posNullableInteger(json['prep_minutes']),
      categoryNameAr: posText(json['category_name_ar']),
      categoryNameEn: posText(json['category_name_en']),
      unitPrice: posNumber(json['unit_price']),
      regularPrice: posNumber(json['regular_price']),
      discountPercentage: posNumber(json['discount_percentage']),
      isAvailable: json.containsKey('is_available')
          ? posFlag(json['is_available'])
          : true,
      unavailableReason: posTextOrNull(json['unavailable_reason']),
      stockQuantity: posInteger(json['stock_quantity']),
      trackStock: posFlag(json['track_stock']),
      allowNegative: posFlag(json['allow_negative']),
      soldOut: posFlag(json['sold_out']),
      optionGroups: posMaps(json['option_groups'])
          .map(PosOptionGroup.fromJson)
          .toList(growable: false),
    );
  }
}

/// Everything the point of sale needs for one branch.
class PosCatalog {
  const PosCatalog({
    this.branchId = '',
    this.currencyCode = 'SAR',
    this.taxRate = 0,
    this.taxIncluded = true,
    this.branches = const <PosBranch>[],
    this.categories = const <PosCategory>[],
    this.paymentMethods = const <PosPaymentMethod>[],
    this.products = const <PosProduct>[],
  });

  final String branchId;
  final String currencyCode;
  final double taxRate;
  final bool taxIncluded;
  final List<PosBranch> branches;
  final List<PosCategory> categories;
  final List<PosPaymentMethod> paymentMethods;
  final List<PosProduct> products;

  PosBranch? branchById(String? id) {
    if (id == null) return null;
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  PosPaymentMethod? paymentById(String? id) {
    if (id == null) return null;
    for (final method in paymentMethods) {
      if (method.id == id) return method;
    }
    return null;
  }

  PosProduct? productById(String? id) {
    if (id == null) return null;
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  PosPaymentMethod? get preferredPaymentMethod {
    for (final method in paymentMethods) {
      if (method.isCash) return method;
    }
    return paymentMethods.isEmpty ? null : paymentMethods.first;
  }

  factory PosCatalog.fromJson(Map<String, dynamic> json) {
    return PosCatalog(
      branchId: posText(json['branch_id']),
      currencyCode: posText(json['currency_code']).isEmpty
          ? 'SAR'
          : posText(json['currency_code']),
      taxRate: posNumber(json['tax_rate']),
      taxIncluded:
          !json.containsKey('tax_included') || posFlag(json['tax_included']),
      branches: posMaps(json['branches'])
          .map(PosBranch.fromJson)
          .toList(growable: false),
      categories: posMaps(json['categories'])
          .map(PosCategory.fromJson)
          .toList(growable: false),
      paymentMethods: posMaps(json['payment_methods'])
          .map(PosPaymentMethod.fromJson)
          .where((method) => method.isCounterTender)
          .toList(growable: false),
      products: posMaps(json['products'])
          .map(PosProduct.fromJson)
          .toList(growable: false),
    );
  }
}
