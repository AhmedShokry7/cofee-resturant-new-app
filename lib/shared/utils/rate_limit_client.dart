import 'dart:convert';

import 'package:new_coffee/core/services/supabase_service.dart';

/// عميل لاستدعاء Edge Function لتقليل المعدل (Rate Limiting) قبل العمليات
/// الحساسة (إرسال طلب، استبدال سلة، بحث).
///
/// يتم استدعاء الدالة عبر Supabase Edge Functions. إذا تعطلت البنية التحتية
/// أو لم تُنشر الدالة بعد، تُفشل العملية abierta (fail open) بحيث يظل التطبيق
/// قابلاً للاستخدام.
class RateLimitClient {
  RateLimitClient._();

  static final RateLimitClient _instance = RateLimitClient._();

  factory RateLimitClient() => _instance;

  /// التحقق من إمكانية تنفيذ [endpoint] للمستخدم الحالي.
  ///
  /// يعيد [true] إذا كان مسموحاً، [false] إذا تجاوز الحد. في حالة تعطل
  /// البنية التحتية أو عدم تهيئة Supabase، يعيد [true] (fail open) حتى لا
  /// يتعطل التطبيق في بيئة التطوير أو الاختبار.
  Future<bool> check(String endpoint) async {
    if (!SupabaseService.isReady) return true;

    final client = SupabaseService.client;

    try {
      final response = await client.functions.invoke(
        'rate-limit',
        body: <String, dynamic>{
          'user_id': client.auth.currentUser?.id,
          'endpoint': endpoint,
          'cost': 1,
        },
        // أن الوصول到这里 يتطلب مصادقة؛ Supabase يرفق JWT تلقائياً.
      );

      final data = _asJsonMap(response.data);
      if (data == null) return true;
      return data['allowed'] == true;
    } catch (_) {
      // fail open: إذا تعطلت دالة المعدل أو رجعت برد غير متوقع، اسمح بالطلب حتى
      // لا يتعطل التطبيق.
      //
      // The catch is deliberately not `on Exception`: a `TypeError` is an
      // `Error`, not an `Exception`, so it used to escape this method and
      // abort whatever the caller was doing.
      return true;
    }
  }

  /// Reads the JSON body of an Edge Function response.
  ///
  /// `functions.invoke` already decodes a JSON response: `data` is the parsed
  /// body, not a raw string. The old code did `jsonDecode(response.data as
  /// String)`, which threw
  ///
  ///     type '_Map<String, dynamic>' is not a subtype of type 'String' in type cast
  ///
  /// on every successful call and made every search fail. A body that is still
  /// a string is handled too, so the helper keeps working if the function ever
  /// answers with a non-JSON content type.
  static Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
