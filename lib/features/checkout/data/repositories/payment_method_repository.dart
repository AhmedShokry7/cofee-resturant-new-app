import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moyasar/moyasar.dart';
import 'package:new_coffee/features/payment/data/moyasar_checkout_config.dart';

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
    final methods = [
      for (final row in rows)
        if (row is Map<String, dynamic>) PaymentMethodModel.fromDatabase(row),
    ].where((method) => method.isAvailableOnThisDevice).toList();
    if (methods.any((method) => method.code == 'samsung_pay')) {
      final eligible = await SamsungPayEligibility.isEligible(
        PaymentConfig(
          publishableApiKey: MoyasarCheckoutConfig.publishableKey,
          amount: 100,
          description: 'Wallet availability',
          samsungPay: SamsungPayConfig(
            serviceId: MoyasarCheckoutConfig.samsungPayServiceId,
            merchantName: MoyasarCheckoutConfig.merchantName,
          ),
        ),
      );
      if (!eligible) {
        methods.removeWhere((method) => method.code == 'samsung_pay');
      }
    }
    return methods;
  }
}
