import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/customer_preview_repository.dart';

/// الشريط الموسمي وحرارة الطقس، كما يقرأهما تطبيق العميل.
///
/// الاستعلام منقول من `supabase_product_repository.dart` هناك، بما في ذلك
/// إرسال `p_branch_id` ولو كان فارغًا: حذف المفتاح يجعل PostgREST لا يطابق
/// توقيع الدالة (PGRST202)، والفرع بلا اختيار حالة عند الزبون لا خطأ.
class SupabaseCustomerPreviewRepository implements CustomerPreviewRepository {
  SupabaseCustomerPreviewRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  /// مهلة الطلب: طلب معلق يترك المحاكي منتظرًا إلى الأبد، والمقطع الموسمي
  /// اختيار عند الزبون لا شرط ظهور.
  static const Duration _timeout = Duration(seconds: 5);

  @override
  Future<List<PreviewProduct>> loadFeatured({
    String? branchId,
    int limit = 10,
  }) async {
    final rows = await _supabase.rpc(
      'get_featured',
      params: {'p_branch_id': branchId, 'p_limit': limit},
    );
    return (rows as List)
        .map((row) {
          final m = Map<String, dynamic>.from(row as Map);
          // السعران من الصف: `effective_price` ما يدفعه الزبون الآن، و
          // `regular_price` ما كان يدفعه قبل الخصم. المشطوب يظهر حين يكون الخصم
          // مطبقًا فعلًا، وهي القاعدة نفسها في `FeaturedProduct.hasDiscount`.
          final percentage = _toDouble(m['discount_percentage']) ?? 0;
          final regular = _toDouble(m['regular_price']);
          final effective = _toDouble(m['effective_price']) ?? 0;
          final image = (m['image_url'] as String?)?.trim();
          return PreviewProduct(
            id: '${m['product_id'] ?? ''}',
            nameAr: '${m['name_ar'] ?? ''}',
            nameEn: '${m['name_en'] ?? ''}',
            categoryAr: '${m['category_name_ar'] ?? ''}',
            categoryEn: '${m['category_name_en'] ?? ''}',
            imageUrl: image == null || image.isEmpty ? null : image,
            price: effective,
            oldPrice: percentage > 0 && regular != null && regular > effective
                ? regular
                : null,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<double> loadTemperature({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude&current=temperature_2m',
    );
    // الدالة العلوية بدل عميل يُفتح ويُترك: الاختبار يستبدل الشبكة بـ
    // `http.runWithClient`، ولا عميل يبقى مفتوحًا بعد الطلب.
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw CustomerWeatherException(
        'الطقس: طلب Open-Meteo رجع بالرمز ${response.statusCode}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'];
    final temperature = current is Map
        ? _toDouble(Map<String, dynamic>.from(current)['temperature_2m'])
        : null;
    if (temperature == null) {
      throw const CustomerWeatherException('الطقس: الاستجابة بلا حرارة');
    }
    return temperature;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

/// فشل قراءة الطقس: لا يُفرغ الشاشة، بل يُسقط المقطع الذي يحتاجه وحده.
class CustomerWeatherException implements Exception {
  const CustomerWeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}
