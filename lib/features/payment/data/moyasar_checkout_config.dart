abstract final class MoyasarCheckoutConfig {
  static const enabled = bool.fromEnvironment(
    'USE_MOYASAR',
    defaultValue: false,
  );
  static const publishableKey = String.fromEnvironment(
    'MOYASAR_PUBLISHABLE_KEY',
  );
}
