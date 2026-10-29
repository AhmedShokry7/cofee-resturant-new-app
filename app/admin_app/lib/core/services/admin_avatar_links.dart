import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';

/// روابط عرض لصور العملاء المخزّنة كمسارات في دلو `avatars` الخاص.
///
/// `identity.profiles.avatar_url` يحمل مسارًا لا رابطًا، لأن ترحيلة 084 رفضت
/// تخزين رابط موقّع في العمود: الرابط ينتهي ويبقى العمود يشير إلى ميت. فالعرض
/// إذن يوقّت المسار عند الطلب عبر واجهة التخزين نفسها، التي تقيس سياسة القراءة
/// على دور الموظف (ترحيلة 208)، فلا مفتاح خدمة في التطبيق.
///
/// الاستبدال يجري على شجرة ردّ الـ RPC كلها لا على صف واحد: الصورة تسكن قمة
/// الرد أحيانًا (`admin_customers`) وداخل كائن العميل أحيانًا أخرى
/// (`admin_notifications`)، والمسمّي لكل ذلك واحد هو اسم المفتاح.
///
/// الفشل لا يُلغي صفحة: توقيعٌ مرفوض يترك الصف بمساره فيطبع Placeholder، لأن
/// عطب التخزين ليس سببًا لإخفاء أسماء العملاء ومبالغهم.
class AdminAvatarLinks {
  const AdminAvatarLinks._();

  static const String bucket = 'avatars';

  /// المفاتيح التي تحمل صورة عميل في ردود القاعدة.
  static const Set<String> keys = {'avatar_url', 'customer_avatar_url'};

  /// ثوانٍ تكفي لجولة نظر في جدول؛ لا شيء يُخزَّن بعد انقضائها.
  static const int ttlSeconds = 3600;

  /// قيمة المفتاح إما رابط كامل يصلح كما هو، أو مسار في الدلو الخاص، أو فراغ.
  /// والفراغ يُحسب على أطرافه: عمود «   » بلا صورة لا مسار باسم أبيض.
  static bool _isStoredPath(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://');
  }

  static Future<Map<String, String>> sign(
    Iterable<String> paths, {
    SupabaseClient? client,
  }) async {
    final unique = {
      for (final path in paths)
        if (_isStoredPath(path)) path.trim(),
    };
    if (unique.isEmpty) return const <String, String>{};
    try {
      final results = await (client ?? SupabaseService.client).storage
          .from(bucket)
          .createSignedUrlsResult(unique.toList(growable: false), ttlSeconds);
      return {
        // ملف حُذف من الدلو وبقي مساره في العمود: التوقيع يجيب إخفاقًا لمسار
        // بعينه، فيبقى على حاله ويطبع Placeholder بدل رابط مكسور.
        for (final result in results)
          if (result is SignedUrlSuccess && _isStoredPath(result.path))
            result.path: result.signedUrl,
      };
    } on Object catch (error) {
      debugPrint('[AdminAvatarLinks] signed-url request failed: $error');
      return const <String, String>{};
    }
  }

  /// يوقّع كل صورة في الرد ويعيد الشجرة نفسها روابطها قابلة للعرض.
  static Future<Object?> signTree(
    Object? json, {
    SupabaseClient? client,
  }) async {
    final paths = <String>{};
    _collect(json, paths);
    if (paths.isEmpty) return json;
    return _rewrite(json, await sign(paths, client: client));
  }

  static void _collect(Object? node, Set<String> into) {
    if (node is Map) {
      for (final entry in node.entries) {
        final value = entry.value;
        if (keys.contains(entry.key) && value is String) {
          if (_isStoredPath(value)) into.add(value.trim());
        } else {
          _collect(value, into);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        _collect(item, into);
      }
    }
  }

  static Object? _rewrite(Object? node, Map<String, String> links) {
    if (links.isEmpty) return node;
    if (node is Map) {
      return <String, dynamic>{
        for (final entry in node.entries)
          '${entry.key}': _rewriteValue(entry, links),
      };
    }
    if (node is List) {
      return [for (final item in node) _rewrite(item, links)];
    }
    return node;
  }

  static Object? _rewriteValue(
    MapEntry<dynamic, dynamic> entry,
    Map<String, String> links,
  ) {
    final value = entry.value;
    if (value is String &&
        keys.contains(entry.key) &&
        links.containsKey(value.trim())) {
      return links[value.trim()];
    }
    return _rewrite(value, links);
  }
}
