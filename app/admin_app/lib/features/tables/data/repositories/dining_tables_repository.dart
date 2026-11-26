import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/tables/domain/entities/dining_overview.dart';
import 'package:admin_app/features/tables/domain/entities/dining_reservation_draft.dart';
import 'package:admin_app/features/tables/domain/entities/dining_table_draft.dart';
import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';

/// The dining floor and its guest bookings.
class DiningTablesRepository implements DiningTableRepository {
  DiningTablesRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<DiningOverview> loadOverview({String? branchId}) async {
    try {
      final response = await _supabase.rpc(
        'admin_dining_overview',
        params: {'p_branch_id': _blankToNull(branchId)},
      );
      if (response is Map) {
        final overview = DiningOverview.fromJson(
          Map<String, dynamic>.from(response),
        );
        // The RPC answers an empty floor rather than raising when no branch is
        // in scope, so the null branch id is the only no-branch signal there is.
        if (overview.branchId == null) {
          throw const DiningLoadException(DiningLoadFailure.noBranch);
        }
        final imageRows = await _supabase.rpc(
          'admin_list_dining_table_images',
          params: {'p_branch_id': overview.branchId},
        );
        final layoutRows = await _supabase.rpc(
          'admin_list_dining_table_layout',
          params: {'p_branch_id': overview.branchId},
        );
        final imageUrls = <String, String>{
          for (final row in (imageRows as List? ?? const []).whereType<Map>())
            if (row['image_url'] is String &&
                (row['image_url'] as String).trim().isNotEmpty)
              '${row['id']}': (row['image_url'] as String).trim(),
        };
        final positions = <String, (double, double)>{
          for (final row in (layoutRows as List? ?? const []).whereType<Map>())
            if (row['layout_x'] is num && row['layout_y'] is num)
              '${row['id']}': (
                (row['layout_x'] as num).toDouble(),
                (row['layout_y'] as num).toDouble(),
              ),
        };
        return DiningOverview(
          branchId: overview.branchId,
          branches: overview.branches,
          tables: overview.tables
              .map(
                (table) => table.copyWith(
                  imageUrl: imageUrls[table.id],
                  clearImageUrl: !imageUrls.containsKey(table.id),
                  layoutX: positions[table.id]?.$1,
                  layoutY: positions[table.id]?.$2,
                ),
              )
              .toList(growable: false),
          reservations: overview.reservations,
          metrics: overview.metrics,
        );
      }
      throw const DiningLoadException(DiningLoadFailure.failed);
    } on DiningLoadException {
      rethrow;
    } on PostgrestException catch (error) {
      throw DiningLoadException(_loadFailure(error), error.message);
    } catch (error) {
      throw DiningLoadException(DiningLoadFailure.failed, '$error');
    }
  }

  @override
  Future<DiningTableSaveOutcome> saveTable(DiningTableDraft draft) async {
    try {
      final response = await _supabase.rpc(
        'admin_save_dining_table',
        params: {'p_table': draft.toJson()},
      );
      if (_isOk(response)) {
        final image = await _supabase.rpc(
          'admin_set_dining_table_image',
          params: {
            'p_branch_id': draft.branchId,
            'p_name': draft.name.trim(),
            'p_image_url': draft.imageUrl,
          },
        );
        return _isOk(image)
            ? DiningTableSaveOutcome.saved
            : DiningTableSaveOutcome.failed;
      }
      return switch (_reason(response)) {
        'invalid_name' => DiningTableSaveOutcome.invalidName,
        'invalid_area' => DiningTableSaveOutcome.invalidArea,
        'invalid_capacity' => DiningTableSaveOutcome.invalidCapacity,
        'invalid_note' => DiningTableSaveOutcome.invalidNote,
        'invalid_branch' => DiningTableSaveOutcome.invalidBranch,
        'duplicate_name' => DiningTableSaveOutcome.duplicateName,
        'not_found' => DiningTableSaveOutcome.notFound,
        _ => DiningTableSaveOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? DiningTableSaveOutcome.permissionDenied
          : DiningTableSaveOutcome.failed;
    } catch (_) {
      return DiningTableSaveOutcome.failed;
    }
  }

  @override
  Future<DiningTableMutationOutcome> setTableLayoutPosition(
    String tableId,
    double x,
    double y,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_set_dining_table_layout_position',
        params: {
          'p_table_id': tableId,
          'p_layout_x': x,
          'p_layout_y': y,
        },
      );
      if (_isOk(response)) return DiningTableMutationOutcome.success;
      return switch (_reason(response)) {
        'not_found' => DiningTableMutationOutcome.notFound,
        _ => DiningTableMutationOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? DiningTableMutationOutcome.permissionDenied
          : DiningTableMutationOutcome.failed;
    } catch (_) {
      return DiningTableMutationOutcome.failed;
    }
  }

  @override
  Future<DiningTableMutationOutcome> setTableActive(
    String tableId,
    bool active,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_set_dining_table_active',
        params: {'p_table_id': tableId, 'p_active': active},
      );
      if (_isOk(response)) return DiningTableMutationOutcome.success;
      return switch (_reason(response)) {
        'not_found' => DiningTableMutationOutcome.notFound,
        'in_use' => DiningTableMutationOutcome.inUse,
        _ => DiningTableMutationOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? DiningTableMutationOutcome.permissionDenied
          : DiningTableMutationOutcome.failed;
    } catch (_) {
      return DiningTableMutationOutcome.failed;
    }
  }

  @override
  Future<DiningTableMutationOutcome> deleteTable(String tableId) async {
    try {
      final response = await _supabase.rpc(
        'admin_delete_dining_table',
        params: {'p_table_id': tableId},
      );
      if (_isOk(response)) return DiningTableMutationOutcome.success;
      return switch (_reason(response)) {
        'not_found' => DiningTableMutationOutcome.notFound,
        'in_use' => DiningTableMutationOutcome.inUse,
        'has_history' => DiningTableMutationOutcome.hasHistory,
        _ => DiningTableMutationOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? DiningTableMutationOutcome.permissionDenied
          : DiningTableMutationOutcome.failed;
    } catch (_) {
      return DiningTableMutationOutcome.failed;
    }
  }

  @override
  Future<DiningReservationSaveOutcome> saveReservation(
    DiningReservationDraft draft,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_save_dining_reservation',
        params: {'p_reservation': draft.toJson()},
      );
      if (_isOk(response)) return DiningReservationSaveOutcome.saved;
      return switch (_reason(response)) {
        'invalid_name' => DiningReservationSaveOutcome.invalidName,
        'invalid_phone' => DiningReservationSaveOutcome.invalidPhone,
        'invalid_party' => DiningReservationSaveOutcome.invalidParty,
        'invalid_duration' => DiningReservationSaveOutcome.invalidDuration,
        'invalid_note' => DiningReservationSaveOutcome.invalidNote,
        'invalid_time' => DiningReservationSaveOutcome.invalidTime,
        'invalid_table' => DiningReservationSaveOutcome.invalidTable,
        'party_too_large' => DiningReservationSaveOutcome.partyTooLarge,
        'overlap' => DiningReservationSaveOutcome.overlap,
        'closed_reservation' => DiningReservationSaveOutcome.closedReservation,
        'seated_table_locked' => DiningReservationSaveOutcome.seatedTableLocked,
        'not_found' => DiningReservationSaveOutcome.notFound,
        _ => DiningReservationSaveOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? DiningReservationSaveOutcome.permissionDenied
          : DiningReservationSaveOutcome.failed;
    } catch (_) {
      return DiningReservationSaveOutcome.failed;
    }
  }

  @override
  Future<DiningReservationStatusOutcome> setReservationStatus(
    String reservationId,
    String status,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_set_dining_reservation_status',
        params: {'p_reservation_id': reservationId, 'p_status': status},
      );
      if (_isOk(response)) return DiningReservationStatusOutcome.success;
      return switch (_reason(response)) {
        'invalid_status' => DiningReservationStatusOutcome.invalidStatus,
        'invalid_table' => DiningReservationStatusOutcome.invalidTable,
        'table_busy' => DiningReservationStatusOutcome.tableBusy,
        'too_early' => DiningReservationStatusOutcome.tooEarly,
        'not_found' => DiningReservationStatusOutcome.notFound,
        _ => DiningReservationStatusOutcome.failed,
      };
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? DiningReservationStatusOutcome.permissionDenied
          : DiningReservationStatusOutcome.failed;
    } catch (_) {
      return DiningReservationStatusOutcome.failed;
    }
  }

  static DiningLoadFailure _loadFailure(PostgrestException error) {
    return switch (error.code) {
      '42501' => DiningLoadFailure.permissionDenied,
      _ => DiningLoadFailure.failed,
    };
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) {
    if (response is Map) return '${response['reason'] ?? ''}'.trim();
    return '';
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
