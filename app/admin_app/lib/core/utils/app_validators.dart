import 'package:admin_app/core/constants/app_patterns.dart';
import 'package:admin_app/core/locale/app_strings.dart';

/// قواعد التحقق المشتركة بين نماذج التطبيق.
///
/// الرسائل من [S] حتى تتبع لغة الواجهة، والقواعد نفسها في مكان واحد حتى لا
/// تختلف من شاشة لأخرى.
abstract final class AppValidators {
  /// يتحقق من بريد إلكتروني مطلوب وصحيح الشكل.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return S.emailRequired;
    if (!AppPatterns.email.hasMatch(text)) return S.validEmail;
    return null;
  }

  /// يتحقق من كلمة مرور غير فارغة.
  static String? password(String? value) {
    if ((value ?? '').isEmpty) return S.passwordRequired;
    return null;
  }
}
