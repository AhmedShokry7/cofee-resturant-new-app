import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';

/// Read/write adapter for the finance RPCs exposed to the Admin dashboard.
class TaxInvoiceRepository {
  TaxInvoiceRepository([this._client]);

  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<Map<String, dynamic>> loadConfiguration() async {
    final value = await _supabase.rpc('admin_tax_configuration');
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<void> saveConfiguration({
    required String registrationStatus,
    required double taxRate,
    required bool taxIncluded,
    required bool deliveryFeeTaxable,
  }) async {
    await _supabase.rpc(
      'admin_save_tax_configuration',
      params: {
        'p_registration_status': registrationStatus,
        'p_tax_rate': taxRate,
        'p_tax_included': taxIncluded,
        'p_delivery_fee_taxable': deliveryFeeTaxable,
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadInvoices({
    required DateTime from,
    required DateTime until,
    String? branchId,
    String? search,
  }) async {
    final value = await _supabase.rpc(
      'admin_invoice_history',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_until': until.toUtc().toIso8601String(),
        'p_branch_id': branchId,
        'p_search': search,
      },
    );
    return value is List
        ? value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const [];
  }

  Future<Map<String, dynamic>> loadTaxReport({
    required DateTime from,
    required DateTime until,
    String? branchId,
  }) async {
    final value = await _supabase.rpc(
      'admin_tax_report',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_until': until.toUtc().toIso8601String(),
        'p_branch_id': branchId,
      },
    );
    final report = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final reconciliation = await _supabase.rpc(
      'admin_financial_reconciliation',
      params: {
        'p_from': from.toUtc().toIso8601String(),
        'p_until': until.toUtc().toIso8601String(),
        'p_branch_id': branchId,
      },
    );
    report['reconciliation'] = reconciliation is Map
        ? Map<String, dynamic>.from(reconciliation)
        : const <String, dynamic>{};
    return report;
  }

  Future<Map<String, dynamic>> loadInvoiceDetail(String orderId) async {
    final value = await _supabase.rpc(
      'admin_order_invoice',
      params: {'p_order_id': orderId},
    );
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  /// Obtains a short-lived URL only after the Edge Function rechecks the
  /// caller's staff role, orders.read permission, and branch scope.
  Future<String?> signedInvoiceDocument(String invoiceId) async {
    if (invoiceId.trim().isEmpty) return null;
    final response = await _supabase.functions.invoke(
      'invoice-documents',
      body: {'invoice_id': invoiceId},
    );
    if (response.data is! Map || response.data['status'] != 'ready') {
      return null;
    }
    final url = response.data['signed_url']?.toString();
    final uri = url == null ? null : Uri.tryParse(url);
    final project = Uri.tryParse(AppConfig.supabaseUrl);
    if (uri == null ||
        project == null ||
        uri.scheme != 'https' ||
        uri.host != project.host) {
      return null;
    }
    return uri.toString();
  }

  Future<List<Map<String, dynamic>>> loadBranches() async {
    final value = await _supabase.rpc('admin_branches');
    return value is List
        ? value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const [];
  }
}
