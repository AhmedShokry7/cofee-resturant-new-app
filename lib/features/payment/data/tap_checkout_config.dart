import 'package:new_coffee/core/locale/app_locale.dart';

/// The payload the Tap hosted card form is opened with, built in one place.
///
/// The form shows the amount and speaks the language it is configured with, so
/// both come from what actually applies to this payment: the figure the server
/// charges and the language the customer is reading the app in. Keeping the
/// payload here leaves the page that embeds the form out of that business.
abstract final class TapCheckoutConfig {
  /// The key the SDK tokenizes the card with. The secret key never reaches the
  /// client: the charge itself is created by the server.
  static const String publicKey = String.fromEnvironment('TAP_PUBLIC_KEY');

  static const String defaultCurrency = 'SAR';

  /// [targetId] is the server id of the order or subscription being paid, and
  /// [amount] is what the server charges for it.
  static Map<String, dynamic> payload({
    required String targetId,
    required double amount,
    String currency = defaultCurrency,
  }) {
    return <String, dynamic>{
      'operator': {'publicKey': publicKey},
      'scope': 'Token',
      'purpose': 'Charge',
      'order': {
        'id': targetId,
        'currency': currency,
        'amount': amount,
        'reference': targetId,
        'description': '',
      },
      'customer': {
        'name': [
          {'lang': 'en', 'first': '', 'last': ''}
        ],
        'contact': {'email': ''},
        'editable': false,
      },
      'acceptance': {
        'supportedSchemes': ['VISA', 'MASTERCARD', 'AMERICAN_EXPRESS'],
        'supportedFundSource': ['CREDIT', 'DEBIT'],
        'supportedPaymentAuthentications': ['3DS'],
      },
      'interface': {
        'locale': AppLocale.instance.isArabic ? 'ar' : 'en',
        'theme': 'light',
        'edges': 'curved',
        'colorStyle': 'colored',
        'loader': true,
      },
      'features': {
        'customerCards': {'saveCard': false, 'autoSave': false},
        'acceptanceBadge': true,
      },
    };
  }
}
