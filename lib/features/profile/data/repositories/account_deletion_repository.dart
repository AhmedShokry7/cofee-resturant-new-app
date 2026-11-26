import 'package:new_coffee/core/services/supabase_service.dart';

class AccountDeletionRepository {
  const AccountDeletionRepository({this.currentUserId, this.rpc});

  final String? Function()? currentUserId;
  final Future<dynamic> Function(String name, Map<String, dynamic> params)? rpc;

  String? get _userId => currentUserId != null
      ? currentUserId!.call()
      : SupabaseService.client.auth.currentUser?.id;
  Future<dynamic> _call(String name) => rpc == null
      ? SupabaseService.client.rpc(name)
      : rpc!(name, const <String, dynamic>{});

  Future<String> requestDeletion() async {
    if (_userId == null) throw StateError('Sign in to request account deletion.');
    final id = await _call('request_account_deletion');
    return id.toString();
  }

  Future<Map<String, dynamic>?> currentRequest() async {
    if (_userId == null) return null;
    final result = await _call('my_account_deletion_request');
    if (result is! Map) return null;
    return Map<String, dynamic>.from(result);
  }
}
