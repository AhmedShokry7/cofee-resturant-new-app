import 'package:admin_app/features/payments/data/models/admin_payment.dart';

/// عقد قراءة سجلات المدفوعات.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class PaymentRepository {
  /// يقرأ كل سجلات المدفوعات بترتيب القاعدة.
  Future<List<AdminPayment>> loadPayments();
}
