import 'package:new_coffee/core/locale/app_strings.dart';

/// The field rules every auth form asks for.
///
/// Each screen carried its own copy of "is this field filled in", and none of
/// them checked the *shape* of an address: a missing `@` cost a round trip to
/// the provider, and the provider answered with the one generic failure the
/// customer could not act on. One owner keeps the four forms in step and stops
/// that round trip.
abstract final class AuthFormRules {
  /// An address with an local part, an `@`, a domain and a dot after it.
  ///
  /// Deliberately permissive: the only thing worth refusing here is the shape
  /// a customer typed by mistake. What actually exists is the provider's call.
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return S.emailRequired;
    if (!_email.hasMatch(text)) return S.authInvalidEmail;
    return null;
  }

  static String? name(String? value) =>
      (value ?? '').trim().isEmpty ? S.nameRequired : null;

  /// Signing in: the only question is whether anything was typed.
  ///
  /// Length is never checked here, because refusing a short password on the
  /// way in would lock out the accounts that predate the provider's minimum.
  static String? password(String? value) =>
      (value ?? '').isEmpty ? S.passwordRequired : null;

  static const int _minPasswordLength = 6;

  /// A password the customer is choosing: the provider's own minimum, asked
  /// before the request instead of after it.
  ///
  /// The same floor the profile screen applies, and the one Supabase enforces —
  /// sign-up used to accept two characters, and the account then existed only
  /// long enough to be refused.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return S.passwordRequired;
    if (text.length < _minPasswordLength) return S.passwordMinLength;
    return null;
  }

  /// The confirm field: the same characters, or nothing at all.
  ///
  /// Compared against the raw password, not its trimmed form, because the
  /// provider receives the raw one.
  static String? confirmPassword(String? value, String password) =>
      value != password ? S.passwordsNoMatch : null;

  /// The country the app sells in, so a local number can be completed without
  /// asking the customer to remember a `+`.
  static const String _countryCode = '966';

  /// The only phone shape Supabase accepts: `+`, then 8 to 15 digits.
  ///
  /// The provider is not forgiving here — a number typed as `050 123 4567`
  /// reaches it as an invalid string and the answer is a generic failure the
  /// customer cannot act on. Completing the number locally costs nothing and is
  /// the same rule the field validator and the sign-in call must share, so it
  /// lives here instead of in either of them.
  ///
  /// Returns null when the text is not a number this app can send an SMS to.
  static String? e164Of(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    // `00966…` is the international prefix written as plain digits.
    final national = digits.startsWith('00') ? digits.substring(2) : digits;
    if (text.startsWith('+') || digits.startsWith('00')) {
      return _isLengthOk(national) ? '+$national' : null;
    }
    // A Saudi mobile typed the way it is read out: `05XXXXXXXX`, or the same
    // number without the trunk `0`. Any other shape is left alone rather than
    // given this country code — guessing a country from ten digits would turn a
    // foreign number into a message sent to somebody else.
    final local = national.startsWith('0') ? national.substring(1) : national;
    if (local.startsWith('5')) {
      final full = '$_countryCode$local';
      return _isLengthOk(full) ? '+$full' : null;
    }
    return _isLengthOk(national) ? '+$national' : null;
  }

  static bool _isLengthOk(String digits) =>
      RegExp(r'^[0-9]{8,15}$').hasMatch(digits);

  /// The phone field: filled in, and in a shape a message can be sent to.
  static String? phone(String? value) {
    final text = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (text.isEmpty) return S.phoneRequired;
    return e164Of(text) == null ? S.validPhoneNumber : null;
  }
}
