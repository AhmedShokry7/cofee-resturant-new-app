import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// The live kitchen board and the two actions the kitchen performs.
class AdminKitchenRepository implements KitchenRepository {
  AdminKitchenRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<AdminKitchenBoard> loadBoard({
    String? search,
    String? branchId,
    int limit = 150,
  }) async {
    final response = await _supabase.rpc(
      'admin_kitchen_board',
      params: {
        'p_search': _blankToNull(search),
        'p_branch_id': _blankToNull(branchId),
        'p_limit': limit,
      },
    );
    if (response is Map) {
      return AdminKitchenBoard.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminKitchenBoard();
  }

  @override
  Future<AdminKitchenMetrics> loadMetrics({String? branchId}) async {
    final response = await _supabase.rpc(
      'admin_kitchen_metrics',
      params: {'p_branch_id': _blankToNull(branchId)},
    );
    if (response is Map) {
      return AdminKitchenMetrics.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminKitchenMetrics.empty;
  }

  @override
  Future<AdminKitchenFilters> loadFilters() async {
    final response = await _supabase.rpc('admin_kitchen_filters');
    if (response is Map) {
      return AdminKitchenFilters.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminKitchenFilters.empty;
  }

  @override
  Future<KitchenMutationOutcome> setTicketStatus(
    String ticketId,
    KitchenTicketStatus status,
  ) {
    return _mutate(
      'admin_kitchen_set_ticket_status',
      params: {'p_ticket_id': ticketId, 'p_status': status.value},
    );
  }

  @override
  Future<KitchenMutationOutcome> setItemStatus(
    String itemId,
    KitchenItemStatus status,
  ) {
    return _mutate(
      'admin_kitchen_set_item_status',
      params: {'p_ticket_item_id': itemId, 'p_status': status.value},
    );
  }

  Future<KitchenMutationOutcome> _mutate(
    String rpc, {
    required Map<String, Object?> params,
  }) async {
    try {
      final response = await _supabase.rpc(rpc, params: params);
      if (response is Map && response['ok'] == true) {
        return KitchenMutationOutcome.success;
      }
      return switch (_reason(response)) {
        'not_found' => KitchenMutationOutcome.notFound,
        'invalid_status' => KitchenMutationOutcome.invalidStatus,
        'invalid_transition' => KitchenMutationOutcome.invalidTransition,
        _ => KitchenMutationOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return switch (error.code) {
        '42501' => KitchenMutationOutcome.permissionDenied,
        'P0002' => KitchenMutationOutcome.notFound,
        _ => KitchenMutationOutcome.failed,
      };
    } catch (_) {
      return KitchenMutationOutcome.failed;
    }
  }

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
