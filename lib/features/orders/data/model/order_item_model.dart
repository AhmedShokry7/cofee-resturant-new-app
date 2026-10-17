import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

/// One historical order line.
///
/// Older call sites construct this directly from a live [ProductModel].
/// Repository-backed history instead freezes the catalogue values that were
/// true when the invoice was created: the product may later be renamed,
/// repriced or deleted, and the invoice must not move with it.
class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.product,
    required this.status,
    this.quantity = 1,
    this.orderId = '',
    this.orderNumber = '',
    this.unitPrice,
    this.lineTotal,
    this.note = '',
    this.placedAt,
    this.createdAt,
    this.fulfillmentType = '',
    this.databaseStatus = '',
    this.deliveryFee = 0,
    this.deliveryZoneNameAr,
    this.deliveryZoneNameEn,
    this.deliveryAddressLabel,
    this.deliveryAddressDetails,
  });

  final String id;
  final ProductModel product;
  final OrderStatus status;
  final int quantity;

  /// Header id for cancellation and tracking. Older in-memory models did not
  /// carry it because an order and its single line were conflated.
  final String orderId;

  final String orderNumber;

  /// Frozen invoice values. Null only for pre-database models, where the live
  /// product row is still the correct source.
  final double? unitPrice;
  final double? lineTotal;

  final String note;
  final DateTime? placedAt;

  /// Pickup or delivery, frozen from the order header.
  final String fulfillmentType;

  /// Raw database status (`preparing`, `ready`, ...). The public [status] is
  /// only the customer-facing bucket.
  final String databaseStatus;

  /// Delivery fee actually charged, frozen on the order header. Zero for
  /// pickup and for pre-delivery orders.
  final double deliveryFee;

  /// Zone name frozen into the order's delivery snapshot at placement, so the
  /// invoice keeps showing the zone the customer chose even if it is later
  /// renamed, repriced or deactivated.
  final String? deliveryZoneNameAr;
  final String? deliveryZoneNameEn;

  /// Delivery address frozen at placement. The client never re-reads the live
  /// address book, so editing or archiving an address cannot rewrite history.
  final String? deliveryAddressLabel;
  final String? deliveryAddressDetails;

  /// Whether this order is delivered rather than collected.
  bool get isDelivery => fulfillmentType == 'delivery';

  /// The frozen zone name in the active language, or null for pickup.
  String? get deliveryZoneName {
    if (!isDelivery) return null;
    final ar = deliveryZoneNameAr?.trim() ?? '';
    final en = deliveryZoneNameEn?.trim() ?? '';
    if (ar.isEmpty && en.isEmpty) return null;
    final text = pickText(
      (ar: ar, en: en),
      isArabic: AppLocale.instance.isArabic,
    );
    return text.isEmpty ? null : text;
  }

  /// The frozen address as one display line (`label - details`), or null.
  String? get deliveryAddress {
    if (!isDelivery) return null;
    final label = deliveryAddressLabel?.trim() ?? '';
    final details = deliveryAddressDetails?.trim() ?? '';
    if (label.isEmpty && details.isEmpty) return null;
    if (label.isEmpty) return details;
    if (details.isEmpty) return label;
    return '$label - $details';
  }

  /// Line creation order within an order. Used only to keep the invoice lines
  /// in their stored sequence.
  final DateTime? createdAt;

  /// The price actually charged, not the product's current shelf price.
  double get chargedUnit => unitPrice ?? product.price;

  double get chargedTotal => lineTotal ?? chargedUnit * quantity;

  /// Display identifier: customers recognize the sequential order number, not
  /// the internal UUID.
  String get displayNumber => orderNumber.isNotEmpty ? orderNumber : id;

  factory OrderItemModel.fromDatabase({
    required Map<String, dynamic> order,
    required Map<String, dynamic> item,
  }) {
    final orderMap = Db.asMap(order);
    final itemMap = Db.asMap(item);
    final status = OrderStatus.fromDatabase(
      Db.textOrNull(orderMap['status']),
    );
    final lineId = Db.text(itemMap['id']);
    final productId = Db.textOrNull(itemMap['product_id']);
    final nameAr = Db.textOrNull(itemMap['product_name_ar']);
    final nameEn = Db.textOrNull(itemMap['product_name_en']);
    final unitPrice = Db.asDouble(itemMap['unit_price']);
    final lineTotal = Db.asDouble(itemMap['line_total']);
    final quantity = Db.asInt(itemMap['quantity'], fallback: 1).clamp(1, 99);
    final placedAtValue = Db.textOrNull(orderMap['placed_at']);
    final createdAtValue = Db.textOrNull(itemMap['created_at']);
    final snapshotValue = orderMap['delivery_address_snapshot'];
    final snapshot = snapshotValue is Map
        ? Db.asMap(snapshotValue)
        : const <String, dynamic>{};

    return OrderItemModel(
      id: lineId.isEmpty
          ? 'line-${Db.text(orderMap['id'])}-${itemMap.hashCode}'
          : lineId,
      product: ProductModel(
        id: productId ??
            'removed-product-${lineId.isEmpty ? itemMap.hashCode : lineId}',
        name: nameEn ?? nameAr ?? 'Removed product',
        nameAr: nameAr,
        nameEn: nameEn,
        description: '',
        price: unitPrice,
        image: Db.textOrNull(itemMap['image_snapshot']) ?? AppImages.product,
      ),
      status: status,
      quantity: quantity,
      orderId: Db.text(orderMap['id']),
      orderNumber: Db.text(orderMap['order_number']),
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      note: Db.text(itemMap['note']),
      fulfillmentType: Db.text(orderMap['fulfillment_type']),
      databaseStatus: Db.text(orderMap['status']),
      deliveryFee: Db.asDouble(orderMap['delivery_fee']),
      deliveryZoneNameAr: Db.textOrNull(snapshot['zone_name_ar']),
      deliveryZoneNameEn: Db.textOrNull(snapshot['zone_name_en']),
      deliveryAddressLabel: Db.textOrNull(snapshot['label']),
      deliveryAddressDetails: Db.textOrNull(snapshot['details']),
      placedAt: placedAtValue == null
          ? null
          : DateTime.tryParse(placedAtValue)?.toLocal(),
      createdAt: createdAtValue == null
          ? null
          : DateTime.tryParse(createdAtValue)?.toLocal(),
    );
  }
}
