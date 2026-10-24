import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';

/// The end-to-end test of the pictures of a product.
///
/// It runs against the development project with a real staff session, so the
/// row level security of the database decides what happens. It is skipped
/// unless the environment names the project and the staff account:
///
///   E2E_SUPABASE_URL=... E2E_SUPABASE_KEY=... \
///   E2E_ADMIN_EMAIL=... E2E_ADMIN_PASSWORD=... \
///   flutter test test/product_images_e2e_test.dart
///
/// The test creates one product of its own and removes it again.
void main() {
  final url = const String.fromEnvironment('E2E_SUPABASE_URL');
  final key = const String.fromEnvironment('E2E_SUPABASE_KEY');
  final email = const String.fromEnvironment('E2E_ADMIN_EMAIL');
  final password = const String.fromEnvironment('E2E_ADMIN_PASSWORD');

  final canRun =
      url.isNotEmpty &&
      key.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty;

  test(
    'the pictures of a product work with a real staff session',
    () async {
      final client = SupabaseClient(url, key);
      addTearDown(client.dispose);

      final signIn = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      expect(signIn.user, isNotNull);

      final repository = AdminProductRepository(client);

      // A product of this test, so nothing that already exists is touched.
      final snapshot = await repository.loadCatalog();
      expect(snapshot.categories, isNotEmpty);
      final categoryId = snapshot.categories.first.id;

      final draft = AdminProduct.draft(
        'e2e-${DateTime.now().microsecondsSinceEpoch}',
      );
      final product = await repository.saveProduct(
        draft.copyWith(
          nameAr: 'منتج اختبار الصور',
          nameEn: 'Image E2E product',
          basePrice: 1,
          categoryId: categoryId,
        ),
        branchId: snapshot.branchId,
      );
      addTearDown(() => _cleanUp(client, repository, product.id));

      // 1. A picture that is picked from the device is uploaded and written.
      final images = await repository.uploadProductImage(
        productId: product.id,
        bytes: _png,
        fileName: 'first.png',
        contentType: 'image/png',
      );
      expect(images, hasLength(1));
      expect(images.first.isPrimary, isTrue);

      // 2. The row is in the database.
      final rows = await client
          .from('catalog.product_images')
          .select('id,image_url,is_primary')
          .eq('product_id', product.id);
      expect(rows, hasLength(1));

      // 3. The file is reachable with its public url.
      final publicRead = await http.get(Uri.parse(images.first.imageUrl));
      expect(publicRead.statusCode, 200);

      // 4. The picture of the product is the primary one.
      final productRow = await client
          .from('catalog.products')
          .select('image_url')
          .eq('id', product.id)
          .single();
      expect(productRow['image_url'], images.first.imageUrl);

      // 5. A second picture, and the primary one moves to it.
      final second = await repository.uploadProductImage(
        productId: product.id,
        bytes: _png,
        fileName: 'second.png',
        contentType: 'image/png',
      );
      expect(second, hasLength(2));

      final primary = await repository.setPrimaryProductImage(second.last);
      expect(primary.where((image) => image.isPrimary), hasLength(1));

      final productRow2 = await client
          .from('catalog.products')
          .select('image_url')
          .eq('id', product.id)
          .single();
      expect(
        productRow2['image_url'],
        primary.firstWhere((i) => i.isPrimary).imageUrl,
      );

      // 6. A picture is replaced and the new url is the one that is kept.
      final replaced = await repository.replaceProductImageWithFile(
        image: primary.first,
        bytes: _png,
        fileName: 'replaced.png',
        contentType: 'image/png',
      );
      expect(replaced.first.imageUrl, contains('replaced.png'));

      // 7. A removed picture takes its row with it.
      final removed = await repository.deleteProductImage(replaced.first);
      expect(removed, hasLength(1));

      final rowsAfter = await client
          .from('catalog.product_images')
          .select('id')
          .eq('product_id', product.id);
      expect(rowsAfter, hasLength(1));
    },
    skip: canRun
        ? false
        : 'Set E2E_SUPABASE_URL, E2E_SUPABASE_KEY, E2E_ADMIN_EMAIL and '
              'E2E_ADMIN_PASSWORD to run it against the development project.',
  );

  test(
    'a customer cannot write a picture of a product',
    () async {
      final customerEmail = const String.fromEnvironment('E2E_CUSTOMER_EMAIL');
      final customerPassword = const String.fromEnvironment(
        'E2E_CUSTOMER_PASSWORD',
      );
      if (customerEmail.isEmpty || customerPassword.isEmpty) {
        return;
      }

      final client = SupabaseClient(url, key);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: customerEmail,
        password: customerPassword,
      );

      final repository = AdminProductRepository(client);
      final snapshot = await repository.loadCatalog();
      if (snapshot.products.isEmpty) return;

      await expectLater(
        repository.addProductImage(
          productId: snapshot.products.first.id,
          imageUrl: 'https://example.com/not-allowed.png',
        ),
        throwsA(anything),
      );
    },
    skip: canRun
        ? false
        : 'Set E2E_SUPABASE_URL, E2E_SUPABASE_KEY, E2E_ADMIN_EMAIL and '
              'E2E_ADMIN_PASSWORD to run it against the development project.',
  );
}

/// Removes the product of the test and the files it owns.
Future<void> _cleanUp(
  SupabaseClient client,
  AdminProductRepository repository,
  String productId,
) async {
  try {
    final images = await repository.loadProductImages(productId);
    for (final image in images) {
      await repository.deleteProductImage(image);
    }
    await client
        .from('catalog.product_images')
        .delete()
        .eq('product_id', productId);
    await client.from('catalog.products').delete().eq('id', productId);
  } catch (_) {
    // The cleanup must not fail the test.
  }
}

/// A one pixel picture.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
