import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/auth/admin_session.dart';

/// العقد الذي تعتمد عليه طبقة المجال للتحدث مع المصادقة.
///
/// التنفيذ الفعلي (Supabase) في طبقة البيانات، فلا يعرف المجال أي مكتبة شبكة.
abstract interface class AuthRepository {
  /// يسجّل الدخول ويعيد جلسة الموظف بعد التحقق من سجله.
  Future<Result<AdminSession>> signIn({
    required String email,
    required String password,
  });

  /// يعيد الجلسة المحفوظة، أو `null` إذا لم تكن هناك جلسة صالحة.
  Future<Result<AdminSession?>> restoreSession();

  /// ينهي الجلسة الحالية.
  Future<void> signOut();
}
