import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/domain/entities/hr_json.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// طبقة الاستدعاء الوحيدة لـ RPCs القاعدة في HR.
///
/// 212 لا ترد بغلاف `{ok:false}`: كل رفض استثناء بـ SQLSTATE. هنا يتحول ذلك
/// مرة واحدة إلى `HrRefusal`، فلا تكرر كل شاشة مطابقة أكواد، ولا يبقى رقمٌ
/// مجهول يفسّره كل منفذ على هواه.
abstract final class HrRpc {
  HrRpc._();

  /// استدعاء يجيب بصفوف: القوائم كلها `jsonb` مصفوفة.
  static Future<List<Map<String, dynamic>>> rows(
    SupabaseClient? client,
    String function, {
    Map<String, dynamic>? params,
  }) async => rowsOf(await _send(client, function, params));

  /// استدعاء يجيب بشيء واحد: التفصيل واللوحة وكل ما يكتب.
  static Future<Map<String, dynamic>> object(
    SupabaseClient? client,
    String function, {
    Map<String, dynamic>? params,
  }) async => mapOf(await _send(client, function, params));

  /// تحويل ما ورد من `rpc()` إلى صفوف، بعد أي معالجة مرّت به Payload —
  /// كتوقيع روابط الصور مثلًا.
  static List<Map<String, dynamic>> rowsOf(Object? response) =>
      hrMaps(response);

  /// تحويل ما ورد من `rpc()` إلى كائن واحد.
  static Map<String, dynamic> mapOf(Object? response) => hrMap(response);

  /// تاريخ بصيغة `YYYY-MM-DD` كما تطلبه معاملات `date`، أو null حين لا قيمة.
  ///
  /// تُرسل الحدود تواريخ، لا أوقاتًا: المنطقة التجارية تعرفها القاعدة وحدها،
  /// ولو أرسلت الشاشة وقتًا محليًا لتغيّر اليوم عند حدود نصف ليل المنطقة.
  static String? day(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// طابع زمني كامل بصيغة يقبلها `timestamptz`، أو null حين لا قيمة.
  static String? instant(DateTime? value) => value?.toUtc().toIso8601String();

  static Future<Object?> _send(
    SupabaseClient? client,
    String function,
    Map<String, dynamic>? params,
  ) async {
    try {
      return await (client ?? SupabaseService.client).rpc<dynamic>(
        function,
        params: params,
      );
    } on PostgrestException catch (error) {
      throw HrRefusal(sqlState: error.code ?? '', message: error.message);
    }
  }
}
