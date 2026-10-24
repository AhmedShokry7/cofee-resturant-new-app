import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminAuthRepository {
  AdminAuthRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<AdminSession> signIn({
    required String email,
    required String password,
  }) async {
    final supabase = _supabase;
    final response = await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user == null) {
      throw const AdminAuthException('Sign in failed. Please try again.');
    }

    try {
      return await _loadStaffRecord(supabase);
    } catch (error) {
      await supabase.auth.signOut();
      rethrow;
    }
  }

  Future<AdminSession?> restoreSession() async {
    if (!SupabaseService.isReady) return null;
    final supabase = _supabase;

    if (supabase.auth.currentSession == null) return null;

    try {
      return await _loadStaffRecord(supabase);
    } catch (_) {
      await supabase.auth.signOut();
      return null;
    }
  }

  Future<AdminSession> _loadStaffRecord(SupabaseClient supabase) async {
    // The staff record comes from the function the migration chain creates
    // and grants to the signed-in staff: admin_get_my_staff_record().
    final raw = await supabase.rpc('admin_get_my_staff_record');
    return AdminSession.fromRpc(raw);
  }

  Future<void> signOut() async {
    if (!SupabaseService.isReady) return;
    await _supabase.auth.signOut();
  }
}
