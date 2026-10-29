import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cashier.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/core/models/dining_table.dart';

/// The point-of-sale menu and the counter checkout.
class AdminPosRepository implements PosRepository {
  AdminPosRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<PosCatalog> loadCatalog({String? branchId}) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_catalog',
        params: {'p_branch_id': _blankToNull(branchId)},
      );
      if (response is Map) {
        return PosCatalog.fromJson(Map<String, dynamic>.from(response));
      }
      if (kDebugMode) {
        debugPrint(
          '[POS] loadCatalog returned ${response.runtimeType} instead of a map',
        );
      }
      throw const PosCatalogException(PosCatalogFailure.failed);
    } on PosCatalogException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('loadCatalog', error);
      throw PosCatalogException(_catalogFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('loadCatalog', error, stackTrace);
      throw PosCatalogException(PosCatalogFailure.failed, '$error');
    }
  }

  @override
  Future<List<DiningTable>> loadTables(String branchId) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_tables',
        params: {'p_branch_id': branchId},
      );
      if (response is List) {
        return response
            .whereType<Map>()
            .map(
              (item) => DiningTable.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      }
      if (response == null) return const <DiningTable>[];
      if (kDebugMode) {
        debugPrint(
          '[POS] loadTables returned ${response.runtimeType} instead of a list',
        );
      }
      throw const PosTablesException(PosTablesFailure.failed);
    } on PosTablesException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('loadTables', error);
      throw PosTablesException(_tablesFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('loadTables', error, stackTrace);
      throw PosTablesException(PosTablesFailure.failed, '$error');
    }
  }

  @override
  Future<PosSeatOutcome> seatReservation(String reservationId) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_seat_reservation',
        params: {'p_reservation_id': reservationId},
      );
      if (response is! Map) {
        if (kDebugMode) {
          debugPrint(
            '[POS] seatReservation returned ${response.runtimeType} '
            'instead of a map',
          );
        }
        return PosSeatOutcome.failed;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['ok'] == true) return PosSeatOutcome.success;
      if (kDebugMode) {
        debugPrint('[POS] seatReservation rejected: ${map['reason']}');
      }
      return switch ('${map['reason']}'.trim()) {
        'too_early' => PosSeatOutcome.tooEarly,
        'invalid_status' => PosSeatOutcome.invalidStatus,
        'table_busy' => PosSeatOutcome.tableBusy,
        'invalid_table' => PosSeatOutcome.invalidTable,
        'not_found' => PosSeatOutcome.notFound,
        _ => PosSeatOutcome.failed,
      };
    } on PostgrestException catch (error) {
      _logError('seatReservation', error);
      return error.code == '42501'
          ? PosSeatOutcome.permissionDenied
          : PosSeatOutcome.failed;
    } catch (error, stackTrace) {
      _logError('seatReservation', error, stackTrace);
      return PosSeatOutcome.failed;
    }
  }

  @override
  Future<PosOrderResult> placeOrder({
    required String branchId,
    required List<Map<String, Object?>> lines,
    required String fulfillmentType,
    required String paymentMethodId,
    required String idempotencyKey,
    String? tableId,
    String? note,
    String? customerId,
    List<Map<String, Object?>>? payments,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[POS] placeOrder -> branch=$branchId lines=${lines.length} '
        'table=${tableId ?? 'none'} method=$paymentMethodId '
        'split=${payments != null}',
      );
    }
    try {
      final response = await _supabase.rpc(
        'admin_pos_place_table_order',
        params: {
          'p_branch_id': branchId,
          'p_lines': lines,
          'p_fulfillment_type': fulfillmentType,
          'p_payment_method_id': paymentMethodId,
          'p_idempotency_key': idempotencyKey,
          'p_table_id': tableId,
          'p_note': _blankToNull(note),
          'p_customer_id': _blankToNull(customerId),
          'p_payments': ?payments,
        },
      );
      if (response is Map) {
        if (kDebugMode) {
          final result = Map<String, dynamic>.from(response);
          debugPrint(
            '[POS] placeOrder ok: order=${result['order_number']} '
            'total=${result['grand_total']} reused=${result['reused']}',
          );
        }
        return PosOrderResult.fromJson(Map<String, dynamic>.from(response));
      }
      if (kDebugMode) {
        debugPrint(
          '[POS] placeOrder returned ${response.runtimeType} instead of a map',
        );
      }
      throw const PosCheckoutException(PosCheckoutFailure.failed);
    } on PosCheckoutException {
      rethrow;
    } on PostgrestException catch (error) {
      final failure = _checkoutFailure(error);
      _logError('placeOrder', error);
      if (kDebugMode) {
        debugPrint('[POS] placeOrder mapped to ${failure.name}');
      }
      throw PosCheckoutException(failure, error.message);
    } catch (error, stackTrace) {
      _logError('placeOrder', error, stackTrace);
      throw PosCheckoutException(PosCheckoutFailure.failed, '$error');
    }
  }

  @override
  Future<List<PosCustomer>> searchCustomers({String? query}) async {
    try {
      final response = await AdminAvatarLinks.signTree(
        await _supabase.rpc(
          'admin_pos_customers',
          params: {'p_search': _blankToNull(query), 'p_limit': 20},
        ),
        client: _supabase,
      );
      if (response is List) {
        return response
            .whereType<Map>()
            .map(
              (item) => PosCustomer.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      }
      if (response == null) return const <PosCustomer>[];
      if (kDebugMode) {
        debugPrint(
          '[POS] searchCustomers returned ${response.runtimeType} '
          'instead of a list',
        );
      }
      throw const PosCustomerException(PosCustomerFailure.failed);
    } on PosCustomerException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('searchCustomers', error);
      throw PosCustomerException(_customerFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('searchCustomers', error, stackTrace);
      throw PosCustomerException(PosCustomerFailure.failed, '$error');
    }
  }

  @override
  Future<PosCustomer> createCustomer({
    required String fullName,
    String? phone,
    String? email,
    String? note,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_customer_create',
        params: {
          'p_full_name': fullName.trim(),
          'p_phone': _blankToNull(phone),
          'p_email': _blankToNull(email),
          'p_note': _blankToNull(note),
        },
      );
      if (response is Map) {
        return PosCustomer.fromJson(Map<String, dynamic>.from(response));
      }
      if (kDebugMode) {
        debugPrint(
          '[POS] createCustomer returned ${response.runtimeType} '
          'instead of a map',
        );
      }
      throw const PosCustomerException(PosCustomerFailure.failed);
    } on PosCustomerException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('createCustomer', error);
      throw PosCustomerException(_customerFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('createCustomer', error, stackTrace);
      throw PosCustomerException(PosCustomerFailure.failed, '$error');
    }
  }

  @override
  Future<List<PosCashier>> loadCashiers(String branchId) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_cashiers',
        params: {'p_branch_id': branchId},
      );
      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => PosCashier.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
      if (response == null) return const <PosCashier>[];
      if (kDebugMode) {
        debugPrint(
          '[POS] loadCashiers returned ${response.runtimeType} instead of a list',
        );
      }
      throw const PosShiftException(PosShiftFailure.failed);
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('loadCashiers', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('loadCashiers', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  @override
  Future<PosShift?> loadOpenShift(String branchId) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_shift',
        params: {'p_branch_id': branchId},
      );
      if (response == null) return null;
      if (response is Map) {
        return PosShift.fromJson(Map<String, dynamic>.from(response));
      }
      if (kDebugMode) {
        debugPrint(
          '[POS] loadOpenShift returned ${response.runtimeType} '
          'instead of a map',
        );
      }
      throw const PosShiftException(PosShiftFailure.failed);
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('loadOpenShift', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('loadOpenShift', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  @override
  Future<PosShift> openShift({
    required String branchId,
    required double openingFloat,
    String? note,
    String? cashierId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_open_shift',
        params: {
          'p_branch_id': branchId,
          'p_opening_float': openingFloat,
          'p_note': _blankToNull(note),
          'p_cashier_id': _blankToNull(cashierId),
        },
      );
      final shift = _shiftFrom(response, 'openShift');
      if (kDebugMode) {
        debugPrint(
          '[POS] openShift ok: shift=${shift.id} '
          'float=${shift.openingFloat} alreadyOpen=${shift.alreadyOpen}',
        );
      }
      return shift;
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('openShift', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('openShift', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  @override
  Future<PosShift> recordCashMovement({
    required String shiftId,
    required PosCashMovementKind kind,
    required double amount,
    required String reason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_record_cash_movement',
        params: {
          'p_shift_id': shiftId,
          'p_kind': kind.value,
          'p_amount': amount,
          'p_reason': reason.trim(),
        },
      );
      final shift = _shiftFrom(response, 'recordCashMovement');
      if (kDebugMode) {
        debugPrint(
          '[POS] recordCashMovement ok: shift=$shiftId '
          'kind=${kind.value} amount=$amount',
        );
      }
      return shift;
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('recordCashMovement', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('recordCashMovement', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  @override
  Future<PosShift> closeShift({
    required String shiftId,
    required double countedCash,
    String? closeNote,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_close_shift',
        params: {
          'p_shift_id': shiftId,
          'p_counted_cash': countedCash,
          'p_close_note': _blankToNull(closeNote),
        },
      );
      final shift = _shiftFrom(response, 'closeShift');
      if (kDebugMode) {
        debugPrint(
          '[POS] closeShift ok: shift=$shiftId '
          'expected=${shift.expectedCash} counted=${shift.countedCash} '
          'variance=${shift.variance}',
        );
      }
      return shift;
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('closeShift', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('closeShift', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  @override
  Future<List<PosShift>> loadShiftHistory(
    String branchId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_shifts',
        params: {'p_branch_id': branchId, 'p_limit': limit, 'p_offset': offset},
      );
      if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => PosShift.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
      if (response == null) return const <PosShift>[];
      if (kDebugMode) {
        debugPrint(
          '[POS] loadShiftHistory returned ${response.runtimeType} '
          'instead of a list',
        );
      }
      throw const PosShiftException(PosShiftFailure.failed);
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('loadShiftHistory', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('loadShiftHistory', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  @override
  Future<PosShift> loadShiftDetail(String shiftId) async {
    try {
      final response = await _supabase.rpc(
        'admin_pos_shift_detail',
        params: {'p_shift_id': shiftId},
      );
      return _shiftFrom(response, 'loadShiftDetail');
    } on PosShiftException {
      rethrow;
    } on PostgrestException catch (error) {
      _logError('loadShiftDetail', error);
      throw PosShiftException(_shiftFailure(error), error.message);
    } catch (error, stackTrace) {
      _logError('loadShiftDetail', error, stackTrace);
      throw PosShiftException(PosShiftFailure.failed, '$error');
    }
  }

  static PosShift _shiftFrom(Object? response, String operation) {
    if (response is Map) {
      return PosShift.fromJson(Map<String, dynamic>.from(response));
    }
    if (kDebugMode) {
      debugPrint(
        '[POS] $operation returned ${response.runtimeType} instead of a map',
      );
    }
    throw const PosShiftException(PosShiftFailure.failed);
  }

  static PosShiftFailure _shiftFailure(PostgrestException error) {
    final message = error.message.toLowerCase();
    return switch (error.code) {
      '42501' => PosShiftFailure.permissionDenied,
      'P0002' when message.contains('branch') =>
        PosShiftFailure.branchUnavailable,
      'P0002' => PosShiftFailure.notFound,
      '23514' when message.contains('closed') => PosShiftFailure.alreadyClosed,
      '22023' when message.contains('exceeds the drawer') =>
        PosShiftFailure.insufficientDrawerCash,
      '22023' || '23514' => PosShiftFailure.invalid,
      _ => PosShiftFailure.failed,
    };
  }

  static PosCatalogFailure _catalogFailure(PostgrestException error) {
    return switch (error.code) {
      '42501' => PosCatalogFailure.permissionDenied,
      'P0002' => PosCatalogFailure.noBranch,
      _ => PosCatalogFailure.failed,
    };
  }

  static PosTablesFailure _tablesFailure(PostgrestException error) {
    return switch (error.code) {
      '42501' => PosTablesFailure.permissionDenied,
      'P0002' => PosTablesFailure.noBranch,
      _ => PosTablesFailure.failed,
    };
  }

  static PosCheckoutFailure _checkoutFailure(PostgrestException error) {
    final message = error.message.toLowerCase();
    return switch (error.code) {
      '42501' => PosCheckoutFailure.permissionDenied,
      '23505' => PosCheckoutFailure.conflict,
      'P0002' when message.contains('payment') =>
        PosCheckoutFailure.paymentUnavailable,
      'P0002' when message.contains('customer') =>
        PosCheckoutFailure.customerUnavailable,
      'P0002' => PosCheckoutFailure.branchUnavailable,
      '23514' => _checkViolationFailure(message),
      '22023' => PosCheckoutFailure.invalid,
      _ => PosCheckoutFailure.failed,
    };
  }

  static PosCustomerFailure _customerFailure(PostgrestException error) {
    return switch (error.code) {
      '42501' => PosCustomerFailure.permissionDenied,
      '22023' || '23514' => PosCustomerFailure.invalid,
      _ => PosCustomerFailure.failed,
    };
  }

  /// Prints the backend answer in debug builds so a rejected counter sale can
  /// be traced from the console instead of the generic localized message.
  void _logError(String operation, Object error, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    if (error is PostgrestException) {
      debugPrint(
        '[POS] $operation failed with PostgREST '
        'code=${error.code ?? 'none'}: ${error.message}',
      );
      if (error.details != null) {
        debugPrint('[POS] $operation details: ${error.details}');
      }
      if (error.hint != null) {
        debugPrint('[POS] $operation hint: ${error.hint}');
      }
    } else {
      debugPrint('[POS] $operation failed: $error');
    }
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  static PosCheckoutFailure _checkViolationFailure(String message) {
    if (message.contains('open a cashier shift')) {
      return PosCheckoutFailure.shiftRequired;
    }
    if (message.contains('table is occupied') ||
        message.contains('table is reserved') ||
        message.contains('table is not available')) {
      return PosCheckoutFailure.tableUnavailable;
    }
    if (message.contains('insufficient stock')) {
      return PosCheckoutFailure.stockUnavailable;
    }
    if (message.contains('not available')) {
      return PosCheckoutFailure.productUnavailable;
    }
    return PosCheckoutFailure.invalid;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
