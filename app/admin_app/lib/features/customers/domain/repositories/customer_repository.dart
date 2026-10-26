import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';

/// عقد قراءة العملاء ومؤشراتهم وتحديث ملف العميل.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class CustomerRepository {
  /// يقرأ كل العملاء كما تعيدهم دالة `admin_customers` بترتيب القاعدة.
  Future<List<AdminCustomer>> loadCustomers();

  /// يقرأ مؤشرات شاشة العملاء من `admin_customer_metrics`.
  Future<AdminCustomerMetrics> loadMetrics();

  /// يقرأ تفاصيل عميل واحد كما جاءت من القاعدة.
  Future<Map<String, dynamic>> loadCustomerDetails(String customerId);

  /// يحدّث وسوم العميل وملاحظاته الإدارية.
  Future<void> updateCustomer(
    String customerId, {
    bool? isVip,
    bool? isBlacklisted,
    String? adminNotes,
  });
}
