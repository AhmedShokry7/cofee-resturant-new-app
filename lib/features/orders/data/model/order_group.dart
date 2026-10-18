import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

/// One customer-facing order: its invoice header plus every frozen line.
///
/// The repository returns flat invoice lines; the list groups them so the
/// card shows one entry per order with the real header totals instead of one
/// card per line. All values are frozen snapshots from the order header and
/// invoice lines — nothing is re-read from the live catalogue.
class OrderGroup {
  OrderGroup({required this.header, required this.lines});

  /// The first line, which carries every header field (number, date, status,
  /// totals, delivery snapshot).
  final OrderItemModel header;

  /// The order's invoice lines in stored creation order.
  final List<OrderItemModel> lines;

  String get orderId => header.orderId;

  String get displayNumber => header.displayNumber;

  DateTime? get placedAt => header.placedAt;

  OrderStatus get status => header.status;

  /// Raw server status (`preparing`, `ready`, ...), preserved for tracking.
  String get databaseStatus => header.databaseStatus;

  String get fulfillmentType => header.fulfillmentType;

  bool get isDelivery => header.isDelivery;

  /// Total units across the order's lines.
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  /// The order's real grand total (discount, tax and delivery included),
  /// frozen on the header. Null only for pre-database models.
  double? get grandTotal => header.grandTotal;

  String get currencyCode => header.currencyCode;

  /// Charged delivery fee, frozen on the header. Zero for pickup.
  double get deliveryFee => header.deliveryFee;

  String? get deliveryZoneName => header.deliveryZoneName;

  String? get deliveryAddress => header.deliveryAddress;

  /// Groups invoice lines into orders, preserving the repository's recency
  /// order. Lines without a header id (legacy in-memory models) each form
  /// their own group so nothing is silently merged.
  static List<OrderGroup> fromLines(List<OrderItemModel> lines) {
    final groups = <String, OrderGroup>{};
    final order = <String>[];
    for (final line in lines) {
      final key = line.orderId.isEmpty ? line.id : line.orderId;
      final existing = groups[key];
      if (existing == null) {
        groups[key] = OrderGroup(header: line, lines: [line]);
        order.add(key);
      } else {
        existing.lines.add(line);
      }
    }
    return [for (final key in order) groups[key]!];
  }
}
