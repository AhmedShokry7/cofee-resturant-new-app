import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/auth/data/repositories/admin_auth_repository.dart';

/// Stands in for the Supabase HTTP layer.
///
/// It answers the sign-in call and records the name of every database
/// function the client asks for, so the test can prove which one the
/// repository uses.
class _RecordingClient extends http.BaseClient {
  final List<String> rpcCalls = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (path.startsWith('/auth/v1/token')) {
      return _json(<String, dynamic>{
        'access_token': 'access-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-token',
        'user': <String, dynamic>{
          'id': 'user-1',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'manager@example.com',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }, request: request);
    }

    if (path.startsWith('/rest/v1/rpc/')) {
      rpcCalls.add(path.substring('/rest/v1/rpc/'.length));
      return _json(<String, dynamic>{
        'staff_id': 's1',
        'full_name': 'Manager',
        'email': 'manager@example.com',
        'status': 'active',
        'accepted_at': '2026-01-01T00:00:00Z',
        'roles': <dynamic>[
          <String, dynamic>{
            'role_id': 'r1',
            'role_code': 'branch_manager',
            'branch_id': 'b1',
          },
        ],
        'permissions': <dynamic>[
          <String, dynamic>{
            'branch_id': 'b1',
            'permissions': <String>['catalog.product.write'],
          },
        ],
        'can_manage_all_branches': false,
      }, request: request);
    }

    return _json(<String, dynamic>{}, status: 404, request: request);
  }

  http.StreamedResponse _json(
    Map<String, dynamic> body, {
    int status = 200,
    required http.BaseRequest request,
  }) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
      request: request,
    );
  }
}

void main() {
  test('the sign-in asks the database for the staff record', () async {
    final httpClient = _RecordingClient();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test-key',
      httpClient: httpClient,
    );
    addTearDown(client.dispose);

    final repository = AdminAuthRepository(client);

    await repository.signIn(email: 'manager@example.com', password: 'secret');

    // The function the migration chain creates and grants to the staff.
    expect(httpClient.rpcCalls, <String>['admin_get_my_staff_record']);
    expect(httpClient.rpcCalls, isNot(contains('admin_get_my_admin_record')));
  });

  test('the staff record is read into the session', () async {
    final httpClient = _RecordingClient();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test-key',
      httpClient: httpClient,
    );
    addTearDown(client.dispose);

    final repository = AdminAuthRepository(client);

    final session = await repository.signIn(
      email: 'manager@example.com',
      password: 'secret',
    );

    expect(session.staffId, 's1');
    expect(session.fullName, 'Manager');
    expect(session.email, 'manager@example.com');
    expect(session.status, 'active');
    expect(session.isOwner, isFalse);
    expect(session.hasPermission('catalog.product.write'), isTrue);
    expect(session.hasPermission('admin.staff.write'), isFalse);
    expect(session.canManageAllBranches, isFalse);
  });
}
