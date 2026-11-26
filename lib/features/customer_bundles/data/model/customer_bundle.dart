import 'package:new_coffee/core/data/db_values.dart';

class CustomerBundleItem {
  const CustomerBundleItem({
    required this.id,
    required this.bundleId,
    required this.productId,
    required this.quantity,
    this.productNameAr,
    this.productNameEn,
    this.productImageUrl,
    this.unitPrice,
    this.selectedOptions = const <String, dynamic>{},
    this.note,
  });

  final String id;
  final String bundleId;
  final String productId;
  final int quantity;
  final String? productNameAr;
  final String? productNameEn;
  final String? productImageUrl;
  final double? unitPrice;
  final Map<String, dynamic> selectedOptions;
  final String? note;

  String get displayName => (productNameAr ?? productNameEn ?? productId).trim();

  factory CustomerBundleItem.fromJson(Map<String, dynamic> json) {
    final opts = json['selected_options'];
    return CustomerBundleItem(
      id: Db.text(json['id']),
      bundleId: Db.text(json['bundle_id']),
      productId: Db.text(json['product_id']),
      quantity: Db.asInt(json['quantity'], fallback: 1),
      productNameAr: Db.textOrNull(json['product_name_ar']),
      productNameEn: Db.textOrNull(json['product_name_en']),
      productImageUrl: Db.textOrNull(json['product_image_url'] ?? json['image_url']),
      unitPrice: json['unit_price'] == null ? null : Db.asDouble(json['unit_price']),
      selectedOptions: opts is Map ? Map<String, dynamic>.from(opts) : const <String, dynamic>{},
      note: Db.textOrNull(json['note']),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'product_id': productId,
        'quantity': quantity,
        'selected_options': selectedOptions,
        'note': note,
      };
}

class CustomerBundle {
  const CustomerBundle({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.isFavorite = false,
    this.isActive = true,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
    this.items = const <CustomerBundleItem>[],
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isFavorite;
  final bool isActive;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<CustomerBundleItem> items;

  double get estimatedTotal => items.fold<double>(0, (s, i) => s + (i.unitPrice ?? 0) * i.quantity);

  CustomerBundle copyWith({
    String? name,
    String? description,
    bool? isFavorite,
    bool? isActive,
    DateTime? lastUsedAt,
    List<CustomerBundleItem>? items,
  }) {
    return CustomerBundle(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      isFavorite: isFavorite ?? this.isFavorite,
      isActive: isActive ?? this.isActive,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items ?? this.items,
    );
  }

  factory CustomerBundle.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return CustomerBundle(
      id: Db.text(json['id']),
      userId: Db.text(json['user_id']),
      name: Db.text(json['name'], ''),
      description: Db.textOrNull(json['description']),
      isFavorite: Db.asBool(json['is_favorite']),
      isActive: Db.asBool(json['is_active'], fallback: true),
      lastUsedAt: Db.asDateTimeOrNull(json['last_used_at']),
      createdAt: Db.asDateTimeOrNull(json['created_at']),
      updatedAt: Db.asDateTimeOrNull(json['updated_at']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => CustomerBundleItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <CustomerBundleItem>[],
    );
  }
}
