import 'package:new_coffee/core/services/supabase_read_service.dart';
import 'package:new_coffee/features/menu/data/model/product_review.dart';
import 'package:new_coffee/features/menu/data/repositories/product_reviews_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads published reviews through the `product_review_summary` and
/// `product_review_list` functions (migration 293). Those functions apply the
/// publish filter, the privacy-safe reviewer name and the purchase check.
class SupabaseProductReviewsRepository implements ProductReviewsRepository {
  SupabaseProductReviewsRepository({SupabaseClient? client})
    : _client = client ?? SupabaseReadService.read;

  final SupabaseClient _client;

  @override
  Future<ProductReviewSummary> getSummary(String productId) async {
    final rows = await _client.rpc(
      'product_review_summary',
      params: {'p_product_id': productId},
      get: true,
    ) as List;
    if (rows.isEmpty) return const ProductReviewSummary();
    return ProductReviewSummary.fromRow(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<ProductReview>> getReviews(
    String productId, {
    int limit = 5,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'product_review_list',
      params: {'p_product_id': productId, 'p_limit': limit, 'p_offset': offset},
      get: true,
    ) as List;
    return [
      for (final row in rows)
        ProductReview.fromRow(row as Map<String, dynamic>),
    ];
  }
}
