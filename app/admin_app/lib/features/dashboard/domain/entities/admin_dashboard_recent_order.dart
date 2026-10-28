/// سطر في «أحدث الطلبات» على اللوحة.
///
/// يحمل ما يطبع في السطر فقط، ولا يحمل أسطره: من يريد تفاصيل الطلب يفتح شاشة
/// الطلبات، واللوحة ليست نسخة ثانية منها.
class AdminDashboardRecentOrder {
  const AdminDashboardRecentOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.fulfillmentType,
    required this.grandTotal,
    required this.itemsCount,
    required this.placedAt,
    this.customerName,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String fulfillmentType;
  final double grandTotal;
  final int itemsCount;
  final DateTime placedAt;

  /// فارغ لطلب لم يُسجَّل له عميل، كطلب الفرع بلا اسم.
  final String? customerName;
}
