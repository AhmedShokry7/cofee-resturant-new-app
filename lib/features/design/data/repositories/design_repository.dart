import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/design/data/design_preview_store.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

/// التصميم الذي نشره الموظف، كما يقرأه الزبون من القاعدة.
///
/// القيد أن شاشة الزبون لا تنتظر الشبكة ولا تسقط من أجلها: صف مفقود يعني «لا شيء
/// منشور بعد» فتُرسم شاشة اليوم كما هي، وعطل قراءة يرجع لآخر طبعة صالحة لا إلى
/// لا شيء.
abstract class DesignRepository {
  /// المستند المنشور، أو null حين لم تصل قراءة. الصف المفقود جواب لا عطل:
  /// طبقة محايدة، لا null.
  Future<PublishedDesign?> published({bool forceRefresh = false});

  /// نسخة آخر مستند صالح على الجهاز، أو null لأول تشغيل بلا شبكة.
  Future<PublishedDesign?> lastKnown();
}

class SupabaseDesignRepository implements DesignRepository {
  SupabaseDesignRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  /// الصف الذي يكتبه `admin_publish_app_design` ويقرؤه الزبون من جسر `public`.
  static const String settingsKey = 'app_design_published';

  /// آخر مستند صالح، يبقى بين تشغيلين ليُرسم حين تنقطع الشبكة.
  static const String _persistKey = 'design_published_document';

  static const String _cacheKey = 'design_published';

  /// سقف للقراءة لا للون: إقلاع لا يُحبس خلف شكل، والتجاوز يرجع للنسخة المحفوظة.
  static const Duration _requestTimeout = Duration(seconds: 5);

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) async {
    // معاينة الأدمن تسبق كل شيء: المستند الذي دفعه المحرّر هو ما يُرسم، بلا
    // شبكة ولا cache ولا حفظ — لأن ما يُعاد بعد المعاينة يجب أن يكون منشور
    // اليوم لا مستند تجربة لم يُنشر بعد.
    final override = DesignPreviewStore.instance.document;
    if (override != null) {
      final previewed = PublishedDesign.fromJson(override);
      if (previewed != null) return previewed;
      // مستند المعاينة نفسه لا يُقرأ: لا تكن نشرًا كاذبًا من تجربة تالفة.
    }
    if (!forceRefresh) {
      final cached = CacheManager().get<PublishedDesign>(_cacheKey);
      if (cached != null) return cached;
    }
    final read = await _readRow();
    if (read == null) return await lastKnown();
    // الحفظ يتبع الجواب لا الشكل: قراءة تقول «لا مستند» تمحو النسخة القديمة،
    // لأن الزبون الذي يعمل بلا شبكة يراها بعد أن رآها الموظف وهو يعمل بشبكة.
    if (read.document == null) {
      await SharedPref.setValue(key: _persistKey, value: '');
    } else {
      await SharedPref.setValue(
        key: _persistKey,
        value: jsonEncode(read.document),
      );
    }
    final design = read.design ?? PublishedDesign.none;
    CacheManager().set(_cacheKey, design);
    return design;
  }

  @override
  Future<PublishedDesign?> lastKnown() async {
    final raw = await SharedPref.getValue(key: _persistKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PublishedDesign.fromJson(jsonDecode(raw));
    } catch (error) {
      debugPrint('[Design] النسخة المحفوظة تالفة: $error');
      return null;
    }
  }

  /// null = لم تصل القراءة. غيرها جواب، ولو على مستند لا يُقرأ.
  Future<_ReadResult?> _readRow() async {
    final client = _client;
    if (client == null) return null;
    try {
      final response = await client
          .from('app_settings')
          .select('value')
          .eq('key', settingsKey)
          .eq('is_public', true)
          .limit(1)
          .timeout(_requestTimeout);
      final rows = response as List;
      if (rows.isEmpty || rows.first is! Map) return const _ReadResult();
      final value = (rows.first as Map)['value'];
      final design = PublishedDesign.fromJson(value);
      if (design == null) return const _ReadResult();
      return _ReadResult(design: design, document: value as Map<Object?, Object?>);
    } catch (error) {
      debugPrint('[Design] قراءة المنشور فشلت: $error');
      return null;
    }
  }
}

/// جواب قراءة الصف: ما فُسّر منه، والخام الذي يُحفظ للنسخة الاحتياطية.
class _ReadResult {
  const _ReadResult({this.design, this.document});

  final PublishedDesign? design;
  final Map<Object?, Object?>? document;
}
