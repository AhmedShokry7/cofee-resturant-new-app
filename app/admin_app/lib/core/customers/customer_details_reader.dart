/// قراءة تفاصيل عميل واحد: العقد الذي يكفيه أن يسأل، لا مخزن العملاء كله.
///
/// التنفيذ الفعلي (Supabase) في طبقة بيانات فيتشر العملاء.
abstract interface class CustomerDetailsReader {
  Future<Map<String, dynamic>> loadCustomerDetails(String customerId);
}
