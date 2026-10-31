import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';

/// SQLSTATE الذي رميته قاعدة البيانات، أو null حين لا يكون الخطأ رفضًا منها.
///
/// تبقى الشيفرة ظاهرة لطبقة العرض التي لها كلام خاص بها على رفض بعينه، كسطر
/// في مصفوفة استيراد أو حالة فشل معروفة في نقاط البيع.
String? adminErrorSqlState(Object error) =>
    error is PostgrestException ? error.code : null;

/// الجملة التي تُعرض على الشاشة بدل نص Postgres الخام.
///
/// القاعدة ترفض وترمِي شيفرة SQLSTATE مع نصٍّ إنجليزي تقني؛ الأدمن لا يقرأ
/// ذلك النص، فيُعرض بدلًا منه سبب عربي واحد معروف لكل الشيفرات التي ترميها
/// هذه القاعدة (انظر `supabase/migrations`)، وما لا شيفرة معروفة له يأخذ
/// [fallback] إن كان للصفحة سببها العام، أو السبب العام للصفحة. النص الخام
/// يذهب إلى سجل التطوير وحده، فلا يصل إلى الشاشة ولا إلى سجل الإنتاج.
///
/// [reasons] كتاب عبارات تملكه الصفحة وحدها: مفتاحه مقطع من نص القاعدة
/// بحروفه الصغيرة، وقيمته جملة الصفحة في تلك الحالة بعينها، حين يكون للسبب
/// كلامٌ أدقّ من الشيفرة (نقص المخزون في الطلب مثالًا). تُطابق العبارات من
/// الأطول إلى الأقصر، فلا تُحجب الجملة الأدقّ بأخرى أقصر منها؛ وإذا لم تُطابق
/// واحدة بقي سبب الشيفرة، ثم [fallback].
String adminErrorMessage(
  Object error, {
  String? fallback,
  Map<String, String> reasons = const <String, String>{},
}) {
  // رسالة التطبيق نفسه جاهزة للعرض أصلًا، فلا تُستبدل بسبب عام.
  if (error is AdminProductException) return error.message;

  final code = adminErrorSqlState(error);
  final reason =
      _phraseOf(error, reasons) ??
      (code == null ? null : _sqlStateMessage(code));
  if (kDebugMode) {
    debugPrint('[AdminError] ${code ?? error.runtimeType}: $error');
  }
  return reason ?? fallback ?? S.actionFailedUnexpectedly;
}

/// عبارة الصفحة المطابقة لنص الرفض، وأطول العبارات أولاً حتى لا تبتلعها
/// العبارة الأقصر («order is not editable» و«refunded order is not editable»).
String? _phraseOf(Object error, Map<String, String> reasons) {
  if (reasons.isEmpty || error is! PostgrestException) return null;
  final message = error.message.toLowerCase();
  for (final key
      in (reasons.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))) {
    if (message.contains(key)) return reasons[key];
  }
  return null;
}

/// أسباب الرفض التي تعرفها هذه القاعدة، بالشيفرات التي ترميها دوالها
/// وسياساتها في سلسلة الترحيل (509 مرة 42501، و270 مرة 23514، و263 مرة
/// 22023، و117 مرة P0002 في `supabase/migrations`).
String? _sqlStateMessage(String code) => switch (code) {
  // سياسة RLS أو شرط صلاحية داخل دالة: الكتابة مرفوضة لصاحب الجلسة.
  '42501' => S.errorNoPermission,
  // لا هوية في الجلسة أصلًا (100 و104 و114 و170).
  '28000' => S.errorSignInRequired,
  // قيد فريد: الاسم أو الرمز أو المزيج موجود (080 و101 و123 و175..182 و212).
  '23505' => S.errorAlreadyExists,
  // قيد CHECK أو حالة يرفضها شرط العمل داخل الدالة (23514 و22023 و22003).
  '23514' || '22023' || '22003' || '22P02' => S.errorRejectedValues,
  // عمود مطلوب وصل فارغًا.
  '23502' => S.errorMissingRequiredField,
  // السجل مستخدم في سجلات أخرى (012b و101 و189).
  '23503' => S.errorRecordInUse,
  // «not found» التي ترميها الدوال عند فقد الصف أو تعطّله.
  'P0002' => S.errorRecordNotFound,
  // تزاحم على الصف أو معاملة انتهت صلاحيّتها (113 و135).
  '40001' || '40P01' || '55P03' => S.errorRecordChangedConcurrently,
  _ => null,
};
