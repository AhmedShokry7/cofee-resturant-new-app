import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';

/// عقد قراءة الطلبات وكتابة حالاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class OrderRepository {
  /// يقرأ الطلبات كلها بترتيب القاعدة.
  Future<List<AdminOrder>> loadOrders();

  Future<void> updateOrderStatus(String orderId, String status);

  /// يقرأ مصفوفة الانتقالات المسموحة من `orders.status_transitions` مع صلاحية
  /// الإلغاء لصاحب الجلسة. `null` عند تعذر القراءة، لأن القائمة الفارغة معنى
  /// مختلف: تعني أن الطلب مغلق ولا حالة تليه.
  Future<OrderStatusRules?> loadStatusRules();

  Future<void> updatePaymentStatus(String orderId, String paymentStatus);

  Future<void> addOrderItem(String orderId, String productId, int quantity);

  Future<void> removeOrderItem(String orderItemId);

  /// يوسم الطلب بأنه فُتح، مرة واحدة فقط مهما تكرر فتحه.
  Future<void> markOrderViewed(String orderId);
}
