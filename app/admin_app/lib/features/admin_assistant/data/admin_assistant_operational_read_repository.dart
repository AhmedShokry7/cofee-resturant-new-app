import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AdminAssistantOperationalReadStatus {
  ready,
  permissionDenied,
  unavailable,
}

/// A compact, allowlisted operational aggregate. No raw customer, card,
/// reservation, invoice snapshot, or employee identity fields are retained.
class AdminAssistantOperationalRead {
  const AdminAssistantOperationalRead({
    required this.kind,
    required this.status,
    this.data = const <String, dynamic>{},
  });

  final String kind;
  final AdminAssistantOperationalReadStatus status;
  final Map<String, dynamic> data;
}

/// Assistant-only access to existing, permission-checked operational reads.
/// The server RPCs remain the authority for branch scope; [branchId] must come
/// from application state, never from a model-selected SQL argument.
class AdminAssistantOperationalReadRepository {
  AdminAssistantOperationalReadRepository({this.client, required this.session});

  final SupabaseClient? client;
  final AdminSession? session;

  SupabaseClient get _db => client ?? SupabaseService.client;

  Future<AdminAssistantOperationalRead> loadOrders({
    DateTime? from,
    DateTime? until,
    String? branchId,
  }) => _loadRpc(
    kind: 'orders',
    permission: 'orders.read',
    function: 'admin_assistant_order_metrics',
    params: _windowParams(from: from, until: until, branchId: branchId),
    sanitizer: sanitizeOrderMetrics,
  );

  Future<AdminAssistantOperationalRead> loadPayments({
    DateTime? from,
    DateTime? until,
    String? branchId,
  }) => _loadRpc(
    kind: 'payments',
    permission: 'payments.read',
    function: 'admin_assistant_payment_metrics',
    params: _windowParams(from: from, until: until, branchId: branchId),
    sanitizer: sanitizePaymentMetrics,
  );

  Future<AdminAssistantOperationalRead> loadDining({String? branchId}) =>
      _loadRpc(
        kind: 'dining',
        permission: 'tables.read',
        function: 'admin_assistant_dining_summary',
        params: <String, dynamic>{'p_branch_id': _blankToNull(branchId)},
        sanitizer: sanitizeDiningSummary,
      );

  Future<AdminAssistantOperationalRead> loadInventoryMovements({
    String? branchId,
    String? period,
  }) => _loadRpc(
    kind: 'inventory_movements',
    permission: 'inventory.read',
    function: 'admin_stock_movement_metrics',
    params: <String, dynamic>{
      'p_branch_id': _blankToNull(branchId),
      'p_period': _blankToNull(period),
    },
    sanitizer: sanitizeInventoryMovementMetrics,
  );

  Future<AdminAssistantOperationalRead> _loadRpc({
    required String kind,
    required String permission,
    required String function,
    required Map<String, dynamic> params,
    required Map<String, dynamic> Function(Map<String, dynamic>) sanitizer,
  }) async {
    if (!(session?.hasPermission(permission) ?? false)) {
      return AdminAssistantOperationalRead(
        kind: kind,
        status: AdminAssistantOperationalReadStatus.permissionDenied,
      );
    }
    try {
      final raw = await _db
          .rpc(function, params: params)
          .timeout(const Duration(seconds: 8));
      if (raw is! Map) {
        return AdminAssistantOperationalRead(
          kind: kind,
          status: AdminAssistantOperationalReadStatus.unavailable,
        );
      }
      final data = sanitizer(Map<String, dynamic>.from(raw));
      return AdminAssistantOperationalRead(
        kind: kind,
        status: AdminAssistantOperationalReadStatus.ready,
        data: Map<String, dynamic>.unmodifiable(data),
      );
    } on PostgrestException catch (error) {
      return AdminAssistantOperationalRead(
        kind: kind,
        status: error.code == '42501'
            ? AdminAssistantOperationalReadStatus.permissionDenied
            : AdminAssistantOperationalReadStatus.unavailable,
      );
    } catch (_) {
      return AdminAssistantOperationalRead(
        kind: kind,
        status: AdminAssistantOperationalReadStatus.unavailable,
      );
    }
  }

  static Map<String, dynamic> sanitizeOrderMetrics(Map<String, dynamic> raw) =>
      <String, dynamic>{
        for (final key in const [
          'from',
          'until',
          'orders',
          'cancelled_orders',
          'completed_orders',
          'average_completed_minutes',
        ])
          if (raw.containsKey(key)) key: raw[key],
        'status_counts': _sanitizeRows(raw['status_counts'], const {
          'status',
          'orders',
        }),
        'fulfillment_counts': _sanitizeRows(raw['fulfillment_counts'], const {
          'fulfillment_type',
          'orders',
          'non_cancelled_orders',
        }),
        'payment_status_counts': _sanitizeRows(
          raw['payment_status_counts'],
          const {'status', 'orders'},
        ),
        'order_totals_by_currency': _sanitizeRows(
          raw['order_totals_by_currency'],
          const {'currency_code', 'orders', 'order_total'},
        ),
        'branch_comparison': _sanitizeRows(raw['branch_comparison'], const {
          'branch_name_ar',
          'branch_name_en',
          'currency_code',
          'orders',
          'non_cancelled_orders',
          'order_total',
        }),
        'invoice_status_counts': _sanitizeRows(
          raw['invoice_status_counts'],
          const {'status', 'invoices'},
        ),
      };

  static Map<String, dynamic> sanitizePaymentMetrics(
    Map<String, dynamic> raw,
  ) => <String, dynamic>{
    for (final key in const ['from', 'until', 'transactions'])
      if (raw.containsKey(key)) key: raw[key],
    'status_counts': _sanitizeRows(raw['status_counts'], const {
      'status',
      'currency_code',
      'transactions',
      'recorded_amount',
    }),
    'refund_status_counts': _sanitizeRows(raw['refund_status_counts'], const {
      'refund_status',
      'transactions',
    }),
    'captured_by_currency': _sanitizeRows(raw['captured_by_currency'], const {
      'currency_code',
      'captured_transactions',
      'captured_transaction_amount',
    }),
    'methods': _sanitizeRows(raw['methods'], const {
      'method_code',
      'method_name_ar',
      'method_name_en',
      'transactions',
      'captured_transactions',
    }),
  };

  static Map<String, dynamic> sanitizeDiningSummary(Map<String, dynamic> raw) {
    final branch = raw['branch'];
    final metrics = raw['metrics'];
    return <String, dynamic>{
      'branch': branch is Map
          ? <String, dynamic>{
              for (final key in const ['name_ar', 'name_en', 'is_active'])
                if (branch.containsKey(key)) key: branch[key],
            }
          : const <String, dynamic>{},
      'metrics': metrics is Map
          ? <String, dynamic>{
              for (final key in const [
                'tables',
                'available',
                'occupied',
                'reserved',
                'reservations_today',
                'upcoming',
              ])
                if (metrics.containsKey(key)) key: metrics[key],
            }
          : const <String, dynamic>{},
      'table_status_counts': _sanitizeRows(raw['table_status_counts'], const {
        'status',
        'tables',
      }),
    };
  }

  static Map<String, dynamic> sanitizeInventoryMovementMetrics(
    Map<String, dynamic> raw,
  ) => <String, dynamic>{
    for (final key in const [
      'total',
      'receipts',
      'issues',
      'waste',
      'counts',
      'received_value',
      'issued_value',
      'waste_value',
      'latest_at',
    ])
      if (raw.containsKey(key)) key: raw[key],
  };

  static List<Map<String, dynamic>> _sanitizeRows(
    Object? value,
    Set<String> allowed,
  ) {
    if (value is! List) return const [];
    return List<Map<String, dynamic>>.unmodifiable(
      value.whereType<Map>().map(
        (row) => <String, dynamic>{
          for (final key in allowed)
            if (row.containsKey(key)) key: row[key],
        },
      ),
    );
  }

  static Map<String, dynamic> _windowParams({
    DateTime? from,
    DateTime? until,
    String? branchId,
  }) => <String, dynamic>{
    'p_from': from?.toUtc().toIso8601String(),
    'p_until': until?.toUtc().toIso8601String(),
    'p_branch_id': _blankToNull(branchId),
  };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
