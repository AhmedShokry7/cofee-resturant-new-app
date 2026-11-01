import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/shared/utils/rate_limit_client.dart';

/// Deterministic cover for the rate-limit check that guards the search.
///
/// The check is the first thing every search does, so a mistake in it does not
/// fail one search - it fails all of them. It used to read the edge function
/// response as `jsonDecode(response.data as String)`, but `functions.invoke`
/// already decodes a JSON body and hands back the parsed map. The cast threw
///
///     type '_Map<String, dynamic>' is not a subtype of type 'String' in type cast
///
/// on every successful call. A `TypeError` is an `Error`, not an `Exception`,
/// so the `on Exception` around it never caught it and the whole search failed.
///
/// No database and no network are touched here.
void main() {
  tearDown(() => SupabaseService.debugSetClient(null));

  /// Builds a client whose Edge Function answers with [body].
  SupabaseClient clientAnswering(
    String body, {
    int statusCode = 200,
    String contentType = 'application/json',
  }) {
    return SupabaseClient(
      'https://catalog.test',
      'anon-key',
      httpClient: MockClient((request) async {
        return http.Response(
          body,
          statusCode,
          headers: <String, String>{'content-type': contentType},
          request: request,
        );
      }),
    );
  }

  test(
    'a decoded JSON body is read instead of being cast to a string',
    () async {
      SupabaseService.debugSetClient(
        clientAnswering(
          jsonEncode(<String, dynamic>{
            'allowed': true,
            'limit': 120,
            'remaining': 119,
          }),
        ),
      );

      expect(
        await RateLimitClient().check('search'),
        isTrue,
        reason: 'the edge function allowed the request',
      );
    },
  );

  test('a request over the limit is refused', () async {
    SupabaseService.debugSetClient(
      clientAnswering(
        jsonEncode(<String, dynamic>{
          'allowed': false,
          'limit': 120,
          'remaining': 0,
        }),
      ),
    );

    expect(
      await RateLimitClient().check('search'),
      isFalse,
      reason: 'the edge function refused the request',
    );
  });

  test('a failing edge function fails open', () async {
    SupabaseService.debugSetClient(
      clientAnswering('{"error":"boom"}', statusCode: 500),
    );

    expect(
      await RateLimitClient().check('search'),
      isTrue,
      reason: 'a broken limiter must not break the app',
    );
  });

  test('a body that is not JSON fails open', () async {
    SupabaseService.debugSetClient(
      clientAnswering('not json at all', contentType: 'text/plain'),
    );

    expect(
      await RateLimitClient().check('search'),
      isTrue,
      reason: 'an unreadable answer must not break the app',
    );
  });

  test('no backend at all fails open', () async {
    SupabaseService.debugSetClient(null);

    expect(
      await RateLimitClient().check('search'),
      isTrue,
      reason: 'without a backend there is nothing to limit',
    );
  });
}
