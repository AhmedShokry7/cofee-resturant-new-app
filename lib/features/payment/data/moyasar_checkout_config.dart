import 'moyasar_public_config.dart';

abstract final class MoyasarCheckoutConfig {
  static const stcPayEnabled = bool.fromEnvironment('MOYASAR_STC_PAY_ENABLED');
  static const applePayMerchantId = String.fromEnvironment(
    'MOYASAR_APPLE_PAY_MERCHANT_ID',
  );
  static const samsungPayServiceId = String.fromEnvironment(
    'MOYASAR_SAMSUNG_PAY_SERVICE_ID',
  );
  static const merchantName = String.fromEnvironment(
    'MOYASAR_MERCHANT_NAME',
    defaultValue: 'New Coffee',
  );
  static const enabled = bool.fromEnvironment(
    'USE_MOYASAR',
    defaultValue: true,
  );
  static const publishableKey = String.fromEnvironment(
    'MOYASAR_PUBLISHABLE_KEY',
    defaultValue: MoyasarPublicConfig.publishableKey,
  );
}
