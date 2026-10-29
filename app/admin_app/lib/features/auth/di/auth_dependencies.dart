import 'package:admin_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// نقطة تركيب اعتمادات المصادقة داخل الفيتشر نفسه.
///
/// تُبنى هنا، لا داخل الواجهات: شاشة الدخول وحوار قبول الدعوة يشتركان في نفس
/// تنفيذ العقد، فلا تُفتح جلستان على نفس العميل.
abstract final class AuthDependencies {
  AuthDependencies._();

  static AuthRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static AuthRepository get repository =>
      _repository ??= SupabaseAuthRepository();
}
