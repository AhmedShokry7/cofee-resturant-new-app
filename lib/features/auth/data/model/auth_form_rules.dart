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
}
