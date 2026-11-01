import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Available payment methods.
///
/// Reads the public `payment_methods` view. Whether a method is online, and
/// whether it needs a saved card, comes from the database rather than being
/// assumed in the UI.
abstract class PaymentMethodRepository {
  Future<List<PaymentMethodModel>> activeMethods();
}

class SupabasePaymentMethodRepository implements PaymentMethodRepository {
  SupabasePaymentMethodRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  @override
  Future<List<PaymentMethodModel>> activeMethods() async {
    final client = _client;
    if (client == null) {
      throw StateError('Payment methods need a configured Supabase backend.');
    }

    final rows =
        await client
                .from('payment_methods')
                .select()
                .eq('is_active', true)
                .order('sort_order')
            as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) PaymentMethodModel.fromDatabase(row),
    ].where((method) => method.isAvailableOnThisDevice).toList();
  }
}
