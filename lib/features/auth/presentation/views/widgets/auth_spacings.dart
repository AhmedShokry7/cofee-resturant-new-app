import 'package:new_coffee/core/theme/tokens.dart';

/// Single source of truth for spacing across all auth pages.
///
/// Every auth page (sign in, sign up, forget/reset password, phone, OTP)
/// follows the login page rhythm exactly — change values here and all
/// auth pages stay in sync.
class AuthSpacings {
  const AuthSpacings._();

  /// Above the page title.
  static const double top = AppSpacing.lg;

  /// Between the title and its subtitle.
  static const double titleGap = AppSpacing.xs;

  /// Between the subtitle and the first input.
  static const double headerGap = AppSpacing.lg;

  /// Between the inputs and the primary button.
  static const double fieldsGap = AppSpacing.sm;

  /// Between the primary button and the section below it.
  static const double buttonGap = AppSpacing.lg;

  /// Between stacked lower sections (social / phone / prompts).
  static const double sectionGap = AppSpacing.lg;

  /// Below the last element.
  static const double bottom = AppSpacing.lg;
}
