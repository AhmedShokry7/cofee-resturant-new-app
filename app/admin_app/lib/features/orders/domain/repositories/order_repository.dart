import 'package:admin_app/features/orders/domain/entities/admin_order.dart';

/// عقد قراءة الطلبات وكتابة حالاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class OrderRepository {
  /// يقرأ الطلبات كلها بترتيب القاعدة.
  Future<List<AdminOrder>> loadOrders();

  Future<void> updateOrderStatus(String orderId, String status);

  Future<void> updatePaymentStatus(String orderId, String paymentStatus);

  Future<void> addOrderItem(String orderId, String productId, int quantity);

  Future<void> removeOrderItem(String orderItemId);
}
