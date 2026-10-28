import 'package:supabase_flutter/supabase_flutter.dart';

/// نصّ رفض كتابة: كلام القاعدة نفسه إن وجد، وإلا رسالة الواجهة العامة.
///
/// `orders.update_order_status` و`orders.cancel_order` يشرحان سبب الرفض
/// («transition … is not allowed»، «you do not manage this branch»)، فإخفاء ذلك
/// خلف «عملية فشلت» يترك الموظف يكرّر المحاولة نفسها دون أن يعرف ما الناقص.
/// الأخطاء الرقمية الصرفة (23514 و42501) لا تحمل نصًا مفيدًا، فيبقى النص العام.
String databaseErrorText(Object? error, {required String fallback}) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (message.isNotEmpty && !message.startsWith('{')) return message;
  }
  return fallback;
}
