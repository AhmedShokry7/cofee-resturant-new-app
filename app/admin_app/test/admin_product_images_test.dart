import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/core/catalog/admin_product_exception.dart';

/// A small stand-in for the Supabase HTTP layer.
///
/// It keeps the pictures of the products in memory, so the test can see what
/// the repository wrote and what it left in the bucket.
class _FakeHttpClient extends http.BaseClient {
  final List<String> uploads = <String>[];
  final List<String> removals = <String>[];
  final List<String> requests = <String>[];
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};

  /// The pictures that are in the bucket, by their path.
  final Map<String, List<int>> files = <String, List<int>>{};

  bool failUpload = false;
  bool failWrite = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final body = request is http.Request ? request.body : '';
    requests.add('${request.method} ${request.url.path}');

    if (path.startsWith('/storage/v1/object/')) {
      final objectPath = path.substring('/storage/v1/object/'.length);
      if (request.method == 'POST') {
        if (failUpload) {
          return _json(
            <String, dynamic>{'message': 'upload failed'},
            500,
            request,
          );
        }
        uploads.add(objectPath);
        files[objectPath] = <int>[1, 2, 3];
        return _json(<String, dynamic>{'Key': objectPath}, 200, request);
      }
      if (request.method == 'DELETE') {
        removals.add(body);
        return _json(<dynamic>[], 200, request);
      }
    }

    if (path.contains('/rest/v1/rpc/admin_set_primary_product_image')) {
      if (failWrite) {
        return _json(
          <String, dynamic>{'message': 'write failed'},
          400,
          request,
        );
      }
      final body = jsonDecode(
        request is http.Request ? request.body : '{}',
      ) as Map<String, dynamic>;
      final imageId = body['p_image_id'];
      final productId = body['p_product_id'];
      for (final row in rows.values) {
        if (row['product_id'] != productId) continue;
        row['is_primary'] = row['id'] == imageId;
      }
      return _json(
        <String, dynamic>{
          'product_id': productId,
          'image_id': imageId,
          'image_url': rows['$imageId']?['image_url'],
        },
        200,
        request,
      );
    }

    if (path.contains('/rest/v1/product_images')) {
      if (request.method == 'POST') {
        if (failWrite) {
          return _json(
            <String, dynamic>{'message': 'insert failed'},
            400,
            request,
          );
        }
        final decoded = jsonDecode(body);
        final entries = decoded is List<dynamic>
            ? decoded.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[decoded as Map<String, dynamic>];
        for (final entry in entries) {
          final row = Map<String, dynamic>.from(entry)
            ..['id'] = 'img-${rows.length + 1}'
            ..['sort_order'] = entry['sort_order'] ?? 0
            ..['is_primary'] = entry['is_primary'] ?? false;
          rows['${row['id']}'] = row;
        }
        return _json(<dynamic>[], 201, request);
      }
      if (request.method == 'GET') {
        final query = request.url.queryParameters;
        final productId = (query['product_id'] ?? '').replaceFirst('eq.', '');
        final imageUrl = (query['image_url'] ?? '').replaceFirst('eq.', '');
        final list = rows.values
            .where(
              (row) =>
                  (productId.isEmpty || row['product_id'] == productId) &&
                  (imageUrl.isEmpty || row['image_url'] == imageUrl),
            )
            .toList(growable: false);
        return _json(list, 200, request);
      }
      if (request.method == 'PATCH') {
        if (failWrite) {
          return _json(
            <String, dynamic>{'message': 'write failed'},
            400,
            request,
          );
        }
        final query = request.url.queryParameters;
        final id = (query['id'] ?? '').replaceFirst('eq.', '');
        final productId = (query['product_id'] ?? '').replaceFirst('eq.', '');
        final isPrimary = (query['is_primary'] ?? '').replaceFirst('eq.', '');
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        for (final row in rows.values) {
          if (id.isNotEmpty && row['id'] != id) continue;
          if (productId.isNotEmpty && row['product_id'] != productId) continue;
          if (isPrimary.isNotEmpty && '${row['is_primary']}' != isPrimary) {
            continue;
          }
          row.addAll(decoded);
        }
        return _json(<dynamic>[], 200, request);
      }
      if (request.method == 'DELETE') {
        final id = (request.url.queryParameters['id'] ?? '').replaceFirst(
          'eq.',
          '',
        );
        rows.remove(id);
        return _json(<dynamic>[], 200, request);
      }
    }

    if (path.contains('/rest/v1/products')) {
      return _json(<dynamic>[], 200, request);
    }

    return _json(<String, dynamic>{}, 404, request);
  }

  http.StreamedResponse _json(
    Object body,
    int status,
    http.BaseRequest request,
  ) {
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
  late _FakeHttpClient httpClient;
  late AdminProductRepository repository;

  setUp(() {
    httpClient = _FakeHttpClient();
    repository = AdminProductRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'publishable-test-key',
        httpClient: httpClient,
      ),
    );
  });

  test(
    'the pictures are read and written through the exposed tables',
    () async {
      await repository.uploadProductImage(
        productId: 'p1',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'coffee.png',
        contentType: 'image/png',
      );

      // The tables are addressed without the schema: PostgREST exposes them
      // under their own name, and the address with the schema returns 404.
      expect(
        httpClient.requests.any(
          (call) => call.contains('/rest/v1/product_images'),
        ),
        isTrue,
      );
      expect(
        httpClient.requests.any((call) => call.contains('catalog.')),
        isFalse,
      );
    },
  );

  test('a legacy product image is imported into an empty gallery', () async {
    final images = await repository.loadProductImages(
      'p-legacy',
      fallbackImageUrl: 'https://example.com/legacy.png',
    );

    expect(images, hasLength(1));
    expect(images.single.imageUrl, 'https://example.com/legacy.png');
    expect(images.single.isPrimary, isTrue);
    expect(
      httpClient.requests.where((request) => request.startsWith('POST ')),
      hasLength(1),
    );
  });

  test('a picked file is uploaded and recorded', () async {
    final images = await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'coffee.png',
      contentType: 'image/png',
    );

    expect(httpClient.uploads, hasLength(1));
    // The file lives in the folder of its product.
    expect(httpClient.uploads.first, contains('product-images/products/p1/'));
    expect(httpClient.uploads.first, endsWith('.png'));

    expect(images, hasLength(1));
    expect(images.first.imageUrl, contains('product-images/products/p1/'));
    // The first picture is the one the card shows.
    expect(images.first.isPrimary, isTrue);
  });

  test(
    'a file that is too big is refused before anything is written',
    () async {
      await expectLater(
        repository.uploadProductImage(
          productId: 'p1',
          bytes: Uint8List(AdminProductRepository.maxProductImageBytes + 1),
          fileName: 'big.png',
          contentType: 'image/png',
        ),
        throwsA(isA<AdminProductException>()),
      );
      expect(httpClient.uploads, isEmpty);
      expect(httpClient.rows, isEmpty);
    },
  );

  test('a file of a format the bucket does not accept is refused', () async {
    await expectLater(
      repository.uploadProductImage(
        productId: 'p1',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'coffee.gif',
        contentType: 'image/gif',
      ),
      throwsA(isA<AdminProductException>()),
    );
    expect(httpClient.uploads, isEmpty);
  });

  test('a failed upload writes no picture', () async {
    httpClient.failUpload = true;

    await expectLater(
      repository.uploadProductImage(
        productId: 'p1',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'coffee.png',
        contentType: 'image/png',
      ),
      throwsA(anything),
    );
    expect(httpClient.rows, isEmpty);
  });

  test('a picture that cannot be written leaves no file behind', () async {
    httpClient.failWrite = true;

    await expectLater(
      repository.uploadProductImage(
        productId: 'p1',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'coffee.png',
        contentType: 'image/png',
      ),
      throwsA(anything),
    );
    // The file that no picture points at is removed again.
    expect(httpClient.removals, hasLength(1));
  });

  test('a replaced picture keeps the old one when the write fails', () async {
    final images = await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'coffee.png',
      contentType: 'image/png',
    );
    final first = images.first;

    httpClient.failWrite = true;

    await expectLater(
      repository.replaceProductImageWithFile(
        image: first,
        bytes: Uint8List.fromList(<int>[4, 5, 6]),
        fileName: 'new.png',
        contentType: 'image/png',
      ),
      throwsA(anything),
    );

    // The picture the admin had is still there.
    final remaining = await repository.loadProductImages('p1');
    expect(remaining, hasLength(1));
    expect(remaining.first.id, first.id);
  });

  test('a replaced picture takes the old file out of the bucket', () async {
    final images = await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'coffee.png',
      contentType: 'image/png',
    );

    await repository.replaceProductImageWithFile(
      image: images.first,
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
      fileName: 'new.png',
      contentType: 'image/png',
    );

    // The old file is removed, the new one is the one the picture points at.
    expect(httpClient.removals, hasLength(1));
    final remaining = await repository.loadProductImages('p1');
    expect(remaining.first.imageUrl, isNot(images.first.imageUrl));
    expect(remaining.first.imageUrl, contains('product-images/products/p1/'));
  });

  test('a removed picture takes its file with it', () async {
    final images = await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'coffee.png',
      contentType: 'image/png',
    );

    await repository.deleteProductImage(images.first);

    expect(await repository.loadProductImages('p1'), isEmpty);
    expect(httpClient.removals, hasLength(1));
  });

  test('a picture that is used twice keeps its file', () async {
    final images = await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'coffee.png',
      contentType: 'image/png',
    );
    // The same file is used by a second picture.
    httpClient.rows['img-2'] = <String, dynamic>{
      'id': 'img-2',
      'product_id': 'p1',
      'image_url': images.first.imageUrl,
      'sort_order': 1,
      'is_primary': false,
    };

    await repository.deleteProductImage(images.first);

    // The file is still needed by the other picture.
    expect(httpClient.removals, isEmpty);
  });

  test('the primary picture of a product is the one the card shows', () async {
    await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'one.png',
      contentType: 'image/png',
    );
    await repository.uploadProductImage(
      productId: 'p1',
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
      fileName: 'two.png',
      contentType: 'image/png',
    );

    final all = await repository.loadProductImages('p1');
    final second = all.firstWhere((image) => !image.isPrimary);
    final updated = await repository.setPrimaryProductImage(second);

    expect(updated.where((image) => image.isPrimary), hasLength(1));
    expect(updated.firstWhere((image) => image.isPrimary).id, second.id);
  });
}
