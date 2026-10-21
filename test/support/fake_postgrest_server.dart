import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// An in-process stand-in for the PostgREST endpoint of the real project.
///
/// It exists so the cross-device behaviour can be proven without touching the
/// production database: two independent sessions (two "devices") talk to the
/// same server state, exactly like two phones signed in with the same account.
///
/// The server keeps the same ownership rule the real RLS policies enforce:
/// every read and every write is scoped to the user the bearer token belongs
/// to. A client that asks for another user's rows therefore gets nothing, and
/// a client that tries to write a row for another user is refused. That makes
/// the harness a real check of the isolation the app relies on, not a stub
/// that answers whatever the caller asks for.
class FakePostgrestServer {
  FakePostgrestServer._(this._server);

  static Future<FakePostgrestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = FakePostgrestServer._(server);
    instance._serve();
    return instance;
  }

  final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}';

  /// email -> user id. The bearer token carries the id, so the harness can
  /// scope every request to its owner exactly like RLS does.
  final Map<String, String> users = <String, String>{};

  /// Sessions handed out by the fake token endpoint: token -> user id.
  final Map<String, String> tokens = <String, String>{};

  /// Server-side carts: cart id -> row.
  final Map<String, Map<String, dynamic>> carts = <String, Map<String, dynamic>>{};

  /// Server-side cart lines: cart item id -> row.
  final Map<String, Map<String, dynamic>> cartItems =
      <String, Map<String, dynamic>>{};

  /// Server-side cart line options: row id -> row.
  final Map<String, Map<String, dynamic>> cartItemOptions =
      <String, Map<String, dynamic>>{};

  /// Server-side favourites: "<userId>|<productId>" -> row.
  final Map<String, Map<String, dynamic>> favorites =
      <String, Map<String, dynamic>>{};

  /// Catalogue used by the fake pricing.
  final Map<String, double> productPrices = <String, double>{};

  int _idCounter = 0;
  String _nextId() => 'id-${++_idCounter}';

  /// Every request the harness received, for assertions about what the app
  /// actually asked the server to do.
  final List<String> requestLog = <String>[];

  /// When set, the next write fails with this status. It simulates a network
  /// or permission failure without touching the stored data.
  int? failNextWriteWithStatus;

  /// When set, the next read fails with this status.
  int? failNextReadWithStatus;

  /// Number of writes the harness refused.
  int refusedWrites = 0;

  void _serve() {
    _server.listen((request) async {
      try {
        await _handle(request);
      } catch (error) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'message': '$error'}));
        await request.response.close();
      }
    });
  }

  Future<void> close() => _server.close(force: true);

  String? _userOf(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return null;
    return tokens[header.substring('Bearer '.length).trim()];
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;
    final body = await utf8.decoder.bind(request).join();
    requestLog.add('${request.method} $path${request.uri.query.isEmpty ? '' : '?${request.uri.query}'}');

    if (path.startsWith('/auth/v1/token')) {
      _handleToken(request, body);
      return;
    }
    if (!path.startsWith('/rest/v1/')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final userId = _userOf(request);
    if (userId == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({'message': 'JWT missing'}));
      await request.response.close();
      return;
    }

    final rest = path.substring('/rest/v1/'.length);
    if (rest.startsWith('rpc/')) {
      await _handleRpc(request, userId, rest.substring(4), body);
      return;
    }
    await _handleTable(request, userId, rest, query, body);
  }

  void _handleToken(HttpRequest request, String body) {
    final payload = jsonDecode(body.isEmpty ? '{}' : body) as Map<String, dynamic>;
    final email = payload['email']?.toString() ?? '';
    final userId = users[email];
    if (userId == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({'message': 'invalid login credentials'}));
      request.response.close();
      return;
    }
    final token = 'token-$userId-${++_idCounter}';
    tokens[token] = userId;
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'access_token': token,
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': token,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': email,
          'app_metadata': {'provider': 'email'},
          'user_metadata': <String, dynamic>{},
          'created_at': '2024-01-01T00:00:00Z',
        },
      }),
    );
    request.response.close();
  }

  // --- tables -------------------------------------------------------------

  Future<void> _handleTable(
    HttpRequest request,
    String userId,
    String table,
    Map<String, String> query,
    String body,
  ) async {
    if (request.method == 'GET') {
      if (failNextReadWithStatus != null) {
        final status = failNextReadWithStatus!;
        failNextReadWithStatus = null;
        request.response.statusCode = status;
        request.response.write(jsonEncode({'message': 'read refused'}));
        await request.response.close();
        return;
      }
      final rows = switch (table) {
        'carts' => carts.values
            .where((row) => row['user_id'] == userId)
            .where((row) => _matches(row, query))
            .toList(),
        'cart_items' => cartItems.values
            .where((row) => _matches(row, query))
            .toList(),
        'cart_item_options' => cartItemOptions.values
            .where((row) => _matches(row, query))
            .toList(),
        'customer_favorites' => favorites.values
            .where((row) => row['user_id'] == userId)
            .where((row) => _matches(row, query))
            .toList(),
        _ => <Map<String, dynamic>>[],
      };
      _json(request, rows);
      return;
    }

    if (request.method == 'POST') {
      if (failNextWriteWithStatus != null) {
        final status = failNextWriteWithStatus!;
        failNextWriteWithStatus = null;
        refusedWrites++;
        request.response.statusCode = status;
        request.response.write(jsonEncode({'message': 'write refused'}));
        await request.response.close();
        return;
      }
      if (table != 'customer_favorites') {
        request.response.statusCode = HttpStatus.notImplemented;
        await request.response.close();
        return;
      }
      final decoded = jsonDecode(body) as Object;
      final payloads = decoded is List ? decoded : [decoded];
      final inserted = <Map<String, dynamic>>[];
      for (final payload in payloads.cast<Map<String, dynamic>>()) {
        // The real table has an owner-only policy: a row for somebody else is
        // refused by the database, never stored.
        if (payload['user_id'] != userId) {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.write(
            jsonEncode({
              'code': '42501',
              'message': 'new row violates row-level security policy',
            }),
          );
          await request.response.close();
          return;
        }
        final key = '$userId|${payload['product_id']}';
        if (favorites.containsKey(key)) {
          request.response.statusCode = HttpStatus.conflict;
          request.response.write(
            jsonEncode({'code': '23505', 'message': 'duplicate key'}),
          );
          await request.response.close();
          return;
        }
        final row = {
          'id': _nextId(),
          'user_id': userId,
          'product_id': payload['product_id'],
          'created_at': DateTime.now().toIso8601String(),
        };
        favorites[key] = row;
        inserted.add(row);
      }
      _json(request, inserted);
      return;
    }

    if (request.method == 'DELETE') {
      if (failNextWriteWithStatus != null) {
        final status = failNextWriteWithStatus!;
        failNextWriteWithStatus = null;
        refusedWrites++;
        request.response.statusCode = status;
        request.response.write(jsonEncode({'message': 'write refused'}));
        await request.response.close();
        return;
      }
      final removed = favorites.values
          .where((row) => row['user_id'] == userId)
          .where((row) => _matches(row, query))
          .toList();
      for (final row in removed) {
        favorites.remove('${row['user_id']}|${row['product_id']}');
      }
      _json(request, removed);
      return;
    }

    request.response.statusCode = HttpStatus.notImplemented;
    await request.response.close();
  }

  // --- rpc ----------------------------------------------------------------

  Future<void> _handleRpc(
    HttpRequest request,
    String userId,
    String function,
    String body,
  ) async {
    if (failNextWriteWithStatus != null) {
      final status = failNextWriteWithStatus!;
      failNextWriteWithStatus = null;
      refusedWrites++;
      request.response.statusCode = status;
      request.response.write(jsonEncode({'message': 'write refused'}));
      await request.response.close();
      return;
    }
    final params = jsonDecode(body.isEmpty ? '{}' : body) as Map<String, dynamic>;
    switch (function) {
      case 'replace_cart':
        final rows = _replaceCart(userId, params);
        _json(request, rows);
        return;
      case 'get_or_create_cart':
        final branch = params['p_branch_id']?.toString() ?? '';
        _json(request, _cartFor(userId, branch));
        return;
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }

  String _cartFor(String userId, String branchId) {
    for (final cart in carts.values) {
      if (cart['user_id'] == userId &&
          cart['branch_id'] == branchId &&
          cart['status'] == 'active') {
        return cart['id'] as String;
      }
    }
    final id = _nextId();
    carts[id] = {
      'id': id,
      'user_id': userId,
      'branch_id': branchId,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    };
    return id;
  }

  List<Map<String, dynamic>> _replaceCart(
    String userId,
    Map<String, dynamic> params,
  ) {
    final branchId = params['p_branch_id']?.toString() ?? '';
    final lines = (params['p_lines'] as List?) ?? const [];
    final cartId = _cartFor(userId, branchId);

    final removed = cartItems.values
        .where((row) => row['cart_id'] == cartId)
        .map((row) => row['id'] as String)
        .toList();
    for (final itemId in removed) {
      cartItems.remove(itemId);
      cartItemOptions.removeWhere(
        (_, row) => row['cart_item_id'] == itemId,
      );
    }

    var subtotal = 0.0;
    var itemCount = 0;
    for (final raw in lines.cast<Map<String, dynamic>>()) {
      final productId = raw['product_id']?.toString() ?? '';
      final quantity = (raw['quantity'] as num?)?.toInt() ?? 1;
      final note = raw['note']?.toString() ?? '';
      final optionIds = [
        for (final value in (raw['option_value_ids'] as List? ?? const []))
          value.toString(),
      ]..sort();
      final unitPrice = productPrices[productId] ?? 10.0;
      final itemId = _nextId();
      cartItems[itemId] = {
        'id': itemId,
        'cart_id': cartId,
        'product_id': productId,
        'quantity': quantity,
        'note': note,
        'unit_price': unitPrice,
        'line_total': unitPrice * quantity,
        'created_at': DateTime.now().toIso8601String(),
      };
      for (final optionId in optionIds) {
        final optionRowId = _nextId();
        cartItemOptions[optionRowId] = {
          'id': optionRowId,
          'cart_item_id': itemId,
          'option_value_id': optionId,
          'option_name_ar': optionId,
          'option_name_en': optionId,
          'price_delta': 0,
        };
      }
      subtotal += unitPrice * quantity;
      itemCount += quantity;
    }

    return [
      {
        'cart_id': cartId,
        'item_count': itemCount,
        'subtotal': subtotal,
      },
    ];
  }

  // --- helpers ------------------------------------------------------------

  void _json(HttpRequest request, Object payload) {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    request.response.close();
  }

  /// Applies the PostgREST filters the app actually uses.
  bool _matches(Map<String, dynamic> row, Map<String, String> query) {
    for (final entry in query.entries) {
      if (entry.key == 'select' ||
          entry.key == 'order' ||
          entry.key == 'limit' ||
          entry.key == 'offset' ||
          entry.key == 'on_conflict') {
        continue;
      }
      final column = entry.key;
      final filter = entry.value;
      final value = row[column]?.toString();
      if (filter.startsWith('eq.')) {
        if (value != filter.substring(3)) return false;
      } else if (filter.startsWith('in.')) {
        final wanted = filter
            .substring(3)
            .replaceAll('(', '')
            .replaceAll(')', '')
            .split(',')
            .map((entry) => entry.replaceAll('"', '').trim())
            .toList();
        if (!wanted.contains(value)) return false;
      } else if (filter.startsWith('neq.')) {
        if (value == filter.substring(4)) return false;
      }
    }
    return true;
  }
}
