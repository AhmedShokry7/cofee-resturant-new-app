import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/domain/repositories/review_repository.dart';

class AdminReviewsRepository implements ReviewRepository {
  AdminReviewsRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminReview>> loadReviews() async {
    final response = await _supabase.rpc('admin_reviews');
    if (response is! List) return const <AdminReview>[];
    return response
        .whereType<Map>()
        .map((row) => AdminReview.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<AdminReviewMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_review_metrics');
    if (response is Map) {
      return AdminReviewMetrics.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminReviewMetrics.empty;
  }

  @override
  Future<ReviewMutationOutcome> setPublished(
    String reviewId,
    bool published,
  ) async {
    final response = await _supabase.rpc(
      'admin_set_review_published',
      params: {'p_review_id': reviewId, 'p_published': published},
    );
    if (_isOk(response)) return ReviewMutationOutcome.success;
    return switch (_reason(response)) {
      'not_found' => ReviewMutationOutcome.notFound,
      _ => ReviewMutationOutcome.failed,
    };
  }

  @override
  Future<ReviewMutationOutcome> deleteReview(String reviewId) async {
    final response = await _supabase.rpc(
      'admin_delete_review',
      params: {'p_review_id': reviewId},
    );
    if (_isOk(response)) return ReviewMutationOutcome.success;
    return switch (_reason(response)) {
      'not_found' => ReviewMutationOutcome.notFound,
      _ => ReviewMutationOutcome.failed,
    };
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';
}
