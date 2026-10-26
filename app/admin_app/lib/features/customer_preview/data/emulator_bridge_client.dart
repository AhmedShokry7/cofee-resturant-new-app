import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/emulator_bridge.dart';

class EmulatorBridgeClient implements EmulatorBridge {
  EmulatorBridgeClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'http://127.0.0.1:47831';

  Uri _uri(String path, String token, [Map<String, String>? query]) =>
      Uri.parse(
        '$_baseUrl$path',
      ).replace(queryParameters: <String, String>{'token': token, ...?query});

  @override
  Future<bool> check(String token) async {
    final response = await _client
        .get(_uri('/health', token))
        .timeout(const Duration(seconds: 2));
    return response.statusCode == 200;
  }

  @override
  Future<Uint8List> screenshot(String token) async {
    final response = await _client
        .get(_uri('/screen', token))
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) {
      throw StateError(_error(response));
    }
    return response.bodyBytes;
  }

  @override
  Future<void> tap(String token, int x, int y) =>
      _command(token, '/tap', <String, String>{'x': '$x', 'y': '$y'});

  @override
  Future<void> swipe(
    String token,
    int x1,
    int y1,
    int x2,
    int y2,
    int duration,
  ) => _command(token, '/swipe', <String, String>{
    'x1': '$x1',
    'y1': '$y1',
    'x2': '$x2',
    'y2': '$y2',
    'duration': '$duration',
  });

  @override
  Future<void> key(String token, String key) =>
      _command(token, '/key', <String, String>{'key': key});

  @override
  Future<void> refresh(String token) => _command(token, '/refresh');

  @override
  Future<void> sendText(String token, String value) async {
    final response = await _client
        .post(
          _uri('/text', token),
          headers: const <String, String>{'Content-Type': 'text/plain'},
          body: utf8.encode(value),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw StateError(_error(response));
  }

  Future<void> _command(
    String token,
    String path, [
    Map<String, String>? parameters,
  ]) async {
    final response = await _client
        .post(
          _uri(path, token, parameters),
          headers: const <String, String>{'Content-Type': 'text/plain'},
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw StateError(_error(response));
  }

  String _error(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}
    return S.bridgeRequestFailed(response.statusCode);
  }

  @override
  void dispose() => _client.close();
}
