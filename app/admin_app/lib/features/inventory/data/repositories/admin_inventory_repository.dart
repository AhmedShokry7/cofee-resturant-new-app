import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_metrics.dart';

enum InventoryMaterialSaveOutcome {
  saved,
  duplicateSku,
  invalidName,
  invalidSku,
  invalidCategory,
  invalidUnit,
  invalidCost,
  invalidReorder,
  invalidNotes,
  unitLocked,
  notFound,
  permissionDenied,
  failed,
}

enum InventoryMutationOutcome {
  success,
  notFound,
  hasMovements,
  hasStock,
  inUse,
  permissionDenied,
  failed,
}

enum InventoryMovementOutcome {
  success,
  materialNotFound,
  invalidBranch,
  invalidType,
  invalidQuantity,
  invalidCost,
  insufficientStock,
  noChange,
  permissionDenied,
  failed,
}

/// Raw-material inventory and its movement ledger.
class AdminInventoryRepository {
  AdminInventoryRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<AdminInventoryPage> loadPage({
    String? search,
    String? category,
    String? status,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  }) async {
    final response = await _supabase.rpc(
      'admin_inventory_directory',
      params: {
        'p_search': _blankToNull(search),
        'p_category': _blankToNull(category),
        'p_status': _blankToNull(status),
        'p_branch_id': _blankToNull(branchId),
        'p_limit': pageSize,
        'p_offset': page * pageSize,
      },
    );
    if (response is Map) {
      return AdminInventoryPage.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminInventoryPage();
  }

  Future<AdminInventoryMetrics> loadMetrics({String? branchId}) async {
    final response = await _supabase.rpc(
      'admin_inventory_metrics',
      params: {'p_branch_id': _blankToNull(branchId)},
    );
    if (response is Map) {
      return AdminInventoryMetrics.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminInventoryMetrics.empty;
  }

  Future<AdminInventoryFilters> loadFilters() async {
    final response = await _supabase.rpc('admin_inventory_filters');
    if (response is Map) {
      return AdminInventoryFilters.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminInventoryFilters.empty;
  }

  Future<List<AdminInventoryMaterialOption>> searchMaterials({
    String? search,
    String? branchId,
    int limit = 30,
  }) async {
    final response = await _supabase.rpc(
      'admin_inventory_material_options',
      params: {
        'p_search': _blankToNull(search),
        'p_branch_id': _blankToNull(branchId),
        'p_limit': limit,
      },
    );
    if (response is! List) return const <AdminInventoryMaterialOption>[];
    return response
        .whereType<Map>()
        .map(
          (row) => AdminInventoryMaterialOption.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  Future<InventoryMaterialSaveOutcome> saveMaterial(
    AdminInventoryDraft draft,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_save_inventory_material',
        params: {'p_material': draft.toJson()},
      );
      if (_isOk(response)) return InventoryMaterialSaveOutcome.saved;
      return switch (_reason(response)) {
        'duplicate_sku' => InventoryMaterialSaveOutcome.duplicateSku,
        'invalid_name' => InventoryMaterialSaveOutcome.invalidName,
        'invalid_sku' => InventoryMaterialSaveOutcome.invalidSku,
        'invalid_category' => InventoryMaterialSaveOutcome.invalidCategory,
        'invalid_unit' => InventoryMaterialSaveOutcome.invalidUnit,
        'invalid_cost' => InventoryMaterialSaveOutcome.invalidCost,
        'invalid_reorder' => InventoryMaterialSaveOutcome.invalidReorder,
        'invalid_notes' => InventoryMaterialSaveOutcome.invalidNotes,
        'unit_locked' => InventoryMaterialSaveOutcome.unitLocked,
        'not_found' => InventoryMaterialSaveOutcome.notFound,
        _ => InventoryMaterialSaveOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? InventoryMaterialSaveOutcome.permissionDenied
          : InventoryMaterialSaveOutcome.failed;
    } catch (_) {
      return InventoryMaterialSaveOutcome.failed;
    }
  }

  Future<InventoryMutationOutcome> deleteMaterial(String materialId) async {
    try {
      final response = await _supabase.rpc(
        'admin_delete_inventory_material',
        params: {'p_material_id': materialId},
      );
      if (_isOk(response)) return InventoryMutationOutcome.success;
      return switch (_reason(response)) {
        'not_found' => InventoryMutationOutcome.notFound,
        'has_movements' => InventoryMutationOutcome.hasMovements,
        'has_stock' => InventoryMutationOutcome.hasStock,
        'in_use' => InventoryMutationOutcome.inUse,
        _ => InventoryMutationOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? InventoryMutationOutcome.permissionDenied
          : InventoryMutationOutcome.failed;
    } catch (_) {
      return InventoryMutationOutcome.failed;
    }
  }

  Future<InventoryMovementOutcome> recordMovement(
    AdminStockMovementDraft draft,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_record_inventory_movement',
        params: {'p_movement': draft.toJson()},
      );
      if (_isOk(response)) return InventoryMovementOutcome.success;
      return switch (_reason(response)) {
        'material_not_found' => InventoryMovementOutcome.materialNotFound,
        'invalid_branch' => InventoryMovementOutcome.invalidBranch,
        'invalid_type' => InventoryMovementOutcome.invalidType,
        'invalid_quantity' => InventoryMovementOutcome.invalidQuantity,
        'invalid_cost' => InventoryMovementOutcome.invalidCost,
        'insufficient_stock' => InventoryMovementOutcome.insufficientStock,
        'no_change' => InventoryMovementOutcome.noChange,
        _ => InventoryMovementOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return switch (error.code) {
        '42501' => InventoryMovementOutcome.permissionDenied,
        'P0002' => InventoryMovementOutcome.invalidBranch,
        _ => InventoryMovementOutcome.failed,
      };
    } catch (_) {
      return InventoryMovementOutcome.failed;
    }
  }

  Future<AdminStockMovementPage> loadMovements({
    String? search,
    String? type,
    String? period,
    String? branchId,
    int page = 0,
    int pageSize = 10,
  }) async {
    final response = await _supabase.rpc(
      'admin_stock_movement_directory',
      params: {
        'p_search': _blankToNull(search),
        'p_type': _blankToNull(type),
        'p_period': _blankToNull(period),
        'p_branch_id': _blankToNull(branchId),
        'p_limit': pageSize,
        'p_offset': page * pageSize,
      },
    );
    if (response is Map) {
      return AdminStockMovementPage.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return const AdminStockMovementPage();
  }

  Future<AdminStockMovementMetrics> loadMovementMetrics({
    String? branchId,
    String? period,
  }) async {
    final response = await _supabase.rpc(
      'admin_stock_movement_metrics',
      params: {
        'p_branch_id': _blankToNull(branchId),
        'p_period': _blankToNull(period),
      },
    );
    if (response is Map) {
      return AdminStockMovementMetrics.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminStockMovementMetrics.empty;
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
