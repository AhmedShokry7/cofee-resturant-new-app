import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase client that only answers `rpc`. Repositories under test never
/// touch the rest of the client, so every other member falls through to
/// `noSuchMethod`, exactly like the real one does for unimplemented surface.
class StubSupabaseClient implements SupabaseClient {
  StubSupabaseClient({this.payload, this.error});

  /// The value the awaited `rpc` call resolves to.
  final Object? payload;

  /// When set, the awaited `rpc` call throws it instead of answering.
  final Object? error;

  String? lastRpc;
  Map<String, dynamic>? lastParams;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    lastRpc = fn;
    lastParams = params;
    return StubRpcResult<T>(payload: payload, error: error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The awaitable half of a `PostgrestFilterBuilder`. Only `then` is exercised
/// by a `await client.rpc(...)` call site; the filter and transform builders
/// are reached only by chaining, which these tests never do.
class StubRpcResult<T> implements PostgrestFilterBuilder<T> {
  StubRpcResult({this.payload, this.error});

  final Object? payload;
  final Object? error;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    final thrown = error;
    final source = thrown != null
        ? Future<T>.error(thrown, StackTrace.current)
        : Future<T>.value(payload as T);
    return source.then(onValue, onError: onError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A client that answers each `rpc` by function name and keeps the calls in the
/// order the repository made them.
///
/// Use it when one behaviour crosses more than one function — a write followed
/// by the read that proves what the database stored — where a single payload
/// would answer both calls with the same object.
class StubSupabaseFunctions implements SupabaseClient {
  StubSupabaseFunctions({
    this.responses = const <String, Object?>{},
    this.errors = const <String, Object>{},
  });

  /// What each function answers, by name.
  final Map<String, Object?> responses;

  /// What each function throws instead, by name.
  final Map<String, Object> errors;

  /// Every call, in order: `rpc:<name>`.
  final List<String> events = <String>[];

  /// The params of the last call to each function.
  final Map<String, Map<String, dynamic>> params =
      <String, Map<String, dynamic>>{};

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    events.add('rpc:$fn');
    if (params != null) this.params[fn] = params;
    return StubRpcResult<T>(payload: responses[fn], error: errors[fn]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
