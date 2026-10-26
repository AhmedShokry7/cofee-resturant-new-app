import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/error/failure.dart';
import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/auth/data/models/admin_session_model.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// تنفيذ [AuthRepository] فوق Supabase Auth ووظيفة سجل الموظف.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<Result<AdminSession>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        return const ResultFailure<AdminSession>(UnknownFailure());
      }
      return Success<AdminSession>(await _loadStaffRecord());
    } on AuthException catch (error) {
      // رفض بيانات الدخول له رمز واضح؛ أي خطأ آخر لا يُعرض كبيانات خاطئة.
      // بعض إصدارات الخادم ترسل الحالة فقط بلا رمز، فتُعامل كرفض دخول أيضًا.
      final rejected =
          error.code == 'invalid_credentials' ||
          (error.code == null &&
              (error.statusCode == '400' || error.statusCode == '401'));
      if (rejected) {
        return const ResultFailure<AdminSession>(InvalidCredentialsFailure());
      }
      return ResultFailure<AdminSession>(UnknownFailure(error.message));
    } catch (error) {
      // بلا سجل موظف صالح لا معنى لجلسة Auth، فتُغلق قبل إبلاغ الواجهة.
      await _signOutQuietly();
      return ResultFailure<AdminSession>(_failureFor(error));
    }
  }

  @override
  Future<Result<AdminSession?>> restoreSession() async {
    if (!SupabaseService.isReady) {
      return const Success<AdminSession?>(null);
    }

    final supabase = _supabase;
    if (supabase.auth.currentSession == null) {
      return const Success<AdminSession?>(null);
    }

    try {
      return Success<AdminSession?>(await _loadStaffRecord());
    } catch (_) {
      // جلسة Auth موجودة لكن سجل الموظف غير صالح: تُغلق بهدوء، وهو السلوك
      // نفسه الذي كان متبعًا قبل الفصل بين الطبقات.
      await supabase.auth.signOut();
      return const Success<AdminSession?>(null);
    }
  }

  @override
  Future<void> signOut() async {
    if (!SupabaseService.isReady) return;
    await _supabase.auth.signOut();
  }

  Future<AdminSession> _loadStaffRecord() async {
    // الدالة التي تنشئها سلسلة الترحيلات وتمنحها للموظف المسجّل.
    final raw = await _supabase.rpc('admin_get_my_staff_record');
    return AdminSessionModel.fromRpc(raw).toEntity();
  }

  Future<void> _signOutQuietly() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // الجلسة قد تكون لم تُنشأ أصلًا؛ لا شيء يجب تصحيحه هنا.
    }
  }

  /// يترجم أخطاء الشبكة إلى أنواع [Failure] التي تعرفها الواجهة.
  Failure _failureFor(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      final notStaff =
          message.contains('not an active staff') ||
          message.contains('staff record not found') ||
          message.contains('not authenticated');
      if (notStaff) return const NotActiveStaffFailure();
      return UnknownFailure(error.message);
    }
    if (error is StateError) return const ConfigurationFailure();
    return UnknownFailure(error.toString());
  }
}
