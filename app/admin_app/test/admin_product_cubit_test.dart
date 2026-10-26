import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_state.dart';

class _FakeProductRepository extends AdminProductRepository {
  _FakeProductRepository({this.products = const <AdminProduct>[]});

  final List<AdminProduct> products;

  final List<AdminProduct> saved = <AdminProduct>[];
  final List<String> deleted = <String>[];
  final Set<String> failingDeletes = <String>{};

  /// The offsets the dashboard asked for, in the order they came.
  final List<int> offsets = <int>[];

  /// The words the dashboard looked for.
  final List<String> searches = <String>[];

  /// The pictures the fake holds, per product.
  final Map<String, List<AdminProductImage>> images =
      <String, List<AdminProductImage>>{};

  /// The picture the fake refuses to write, to test a failing action.
  String? failingImageUrl;

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    offsets.add(offset);
    searches.add(search ?? '');

    final term = (search ?? '').trim().toLowerCase();
    final matching = term.isEmpty
        ? products
        : products
              .where(
                (product) =>
                    product.nameAr.toLowerCase().contains(term) ||
                    product.nameEn.toLowerCase().contains(term) ||
                    product.sku.toLowerCase().contains(term),
              )
              .toList(growable: false);

    final page = limit == null
        ? matching
        : matching.skip(offset).take(limit).toList(growable: false);

    return AdminCatalogSnapshot(
      products: page,
      categories: const [],
      branchId: 'branch-1',
      total: matching.length,
    );
  }

  @override
  Future<List<AdminProductImage>> loadProductImages(
    String productId, {
    String? fallbackImageUrl,
  }) async {
    return List<AdminProductImage>.from(images[productId] ?? const []);
  }

  @override
  Future<List<AdminProductImage>> addProductImage({
    required String productId,
    required String imageUrl,
  }) async {
    if (failingImageUrl == imageUrl) {
      throw const AdminProductException('The picture was not saved.');
    }
    final current = images[productId] ?? <AdminProductImage>[];
    final image = AdminProductImage(
      id: 'img-${current.length + 1}',
      productId: productId,
      imageUrl: imageUrl,
      sortOrder: current.length,
      isPrimary: current.isEmpty,
    );
    images[productId] = <AdminProductImage>[...current, image];
    return List<AdminProductImage>.from(images[productId]!);
  }

  @override
  Future<List<AdminProductImage>> updateProductImage({
    required AdminProductImage image,
    required String imageUrl,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    if (failingImageUrl == imageUrl) {
      throw const AdminProductException('The picture was not saved.');
    }
    final current = images[image.productId] ?? <AdminProductImage>[];
    images[image.productId] = current
        .map(
          (entry) => entry.id == image.id
              ? entry.copyWith(
                  imageUrl: imageUrl,
                  fit: fit ?? entry.fit,
                  alignment: alignment ?? entry.alignment,
                )
              : entry,
        )
        .toList(growable: false);
    return List<AdminProductImage>.from(images[image.productId]!);
  }

  @override
  Future<List<AdminProductImage>> updateProductImageSettings({
    required AdminProductImage image,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final current = images[image.productId] ?? <AdminProductImage>[];
    images[image.productId] = current
        .map(
          (entry) => entry.id == image.id
              ? entry.copyWith(
                  fit: fit ?? entry.fit,
                  alignment: alignment ?? entry.alignment,
                )
              : entry,
        )
        .toList(growable: false);
    return List<AdminProductImage>.from(images[image.productId]!);
  }

  @override
  Future<List<AdminProductImage>> applyProductImageSettings({
    required String productId,
    BoxFit? fit,
    Alignment? alignment,
  }) async {
    final current = images[productId] ?? <AdminProductImage>[];
    images[productId] = current
        .map(
          (entry) => entry.copyWith(
            fit: fit ?? entry.fit,
            alignment: alignment ?? entry.alignment,
          ),
        )
        .toList(growable: false);
    return List<AdminProductImage>.from(images[productId]!);
  }

  @override
  Future<List<AdminProductImage>> deleteProductImage(
    AdminProductImage image,
  ) async {
    final current = images[image.productId] ?? <AdminProductImage>[];
    images[image.productId] = current
        .where((entry) => entry.id != image.id)
        .toList(growable: false);
    return List<AdminProductImage>.from(images[image.productId]!);
  }

  @override
  Future<List<AdminProductImage>> setPrimaryProductImage(
    AdminProductImage image,
  ) async {
    final current = images[image.productId] ?? <AdminProductImage>[];
    images[image.productId] = current
        .map((entry) => entry.copyWith(isPrimary: entry.id == image.id))
        .toList(growable: false);
    return List<AdminProductImage>.from(images[image.productId]!);
  }

  @override
  Future<AdminProduct> saveProduct(
    AdminProduct product, {
    String? branchId,
  }) async {
    saved.add(product);
    final stored = product.isDraft
        ? product.copyWith(id: 'p${saved.length}', isDraft: false)
        : product;
    return stored;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    if (failingDeletes.contains(productId)) {
      throw StateError('delete failed');
    }
    deleted.add(productId);
  }

  @override
  Future<void> setFeatured(String productId, bool isFeatured) async {}
}

const AdminProduct _product = AdminProduct(
  id: 'p1',
  nameAr: 'منتج أول',
  nameEn: 'First',
  sku: 'SKU-1',
  slug: 'first',
  basePrice: 10,
  stockQuantity: 5,
);

void main() {
  test('the cubit loads the catalogue of the branch', () async {
    final cubit = AdminProductCubit(
      repository: _FakeProductRepository(
        products: const <AdminProduct>[_product],
      ),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminProductStatus.ready);
    expect(cubit.state.products, hasLength(1));
    expect(cubit.state.products.first.nameAr, 'منتج أول');
    expect(cubit.state.branchId, 'branch-1');
  });

  test('a failed load reports the error', () async {
    final cubit = AdminProductCubit(repository: _FakeProductRepository());
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminProductStatus.ready);
    expect(cubit.state.products, isEmpty);
  });

  test('a draft is written only when the admin saves it', () async {
    final repository = _FakeProductRepository();
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.products, isEmpty);

    final draft = AdminProduct.draft('draft-1')
        .copyWith(nameAr: 'قهوة', categoryId: 'c1');
    expect(cubit.state.products, isEmpty);

    await cubit.saveProduct(draft);

    expect(repository.saved, hasLength(1));
    expect(cubit.state.products, hasLength(1));
    expect(cubit.state.products.first.id, 'p1');
    expect(cubit.state.products.first.isDraft, isFalse);
  });

  test('an edited draft is still a draft, so the database creates the row', () {
    final draft = AdminProduct.draft('draft-1');

    final edited = draft.copyWith(nameAr: 'قهوة', basePrice: 12);

    expect(edited.isDraft, isTrue);
    expect(edited.id, 'draft-1');
    expect(edited.nameAr, 'قهوة');
  });

  test('a saved product tells the admin that it worked', () async {
    final repository = _FakeProductRepository();
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.saveProduct(
      AdminProduct.draft('draft-1').copyWith(nameAr: 'قهوة', categoryId: 'c1'),
    );

    expect(cubit.state.notice, isNotNull);
    expect(cubit.state.errorMessage, isNull);
  });

  test('the admin deletes a product', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.deleteProduct('p1');

    expect(repository.deleted, <String>['p1']);
    expect(cubit.state.products, isEmpty);
  });

  test('the catalogue arrives in pages', () async {
    final repository = _FakeProductRepository(
      products: List<AdminProduct>.generate(
        45,
        (index) => AdminProduct(
          id: 'p$index',
          nameAr: 'منتج $index',
          nameEn: 'Product $index',
          sku: 'SKU-$index',
          slug: 'product-$index',
          basePrice: 10,
        ),
      ),
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.products, hasLength(AdminProductCubit.pageSize));
    expect(cubit.state.total, 45);
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();

    expect(cubit.state.products, hasLength(40));
    expect(cubit.state.hasMore, isTrue);
    // The second page starts where the first one ended.
    expect(repository.offsets, <int>[0, 20]);

    await cubit.loadMore();

    expect(cubit.state.products, hasLength(45));
    expect(cubit.state.hasMore, isFalse);
    expect(repository.offsets, <int>[0, 20, 40]);
  });

  test('select all includes products on every matching page', () async {
    final repository = _FakeProductRepository(
      products: List<AdminProduct>.generate(
        45,
        (index) => AdminProduct(
          id: 'p$index',
          nameAr: 'منتج $index',
          nameEn: 'Product $index',
          sku: 'SKU-$index',
          slug: 'product-$index',
          basePrice: 10,
        ),
      ),
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.selectAllProducts();

    expect(cubit.state.selectedIds, hasLength(45));
    expect(cubit.state.selectedIds, containsAll(<String>['p0', 'p20', 'p44']));
    expect(repository.offsets, <int>[0, 20, 40]);
    expect(cubit.state.isSelectingAll, isFalse);
  });

  test(
    'bulk delete removes successful products and keeps failures selected',
    () async {
      final repository = _FakeProductRepository(
        products: const <AdminProduct>[
          _product,
          AdminProduct(
            id: 'p2',
            nameAr: 'منتج ثاني',
            nameEn: 'Second',
            sku: 'SKU-2',
            slug: 'second',
            basePrice: 20,
          ),
          AdminProduct(
            id: 'p3',
            nameAr: 'منتج ثالث',
            nameEn: 'Third',
            sku: 'SKU-3',
            slug: 'third',
            basePrice: 30,
          ),
        ],
      )..failingDeletes.add('p2');
      final cubit = AdminProductCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.selectAllProducts();
      await cubit.deleteSelectedProducts();

      expect(repository.deleted, containsAll(<String>['p1', 'p3']));
      expect(repository.deleted, isNot(contains('p2')));
      expect(cubit.state.products.map((product) => product.id), <String>['p2']);
      expect(cubit.state.selectedIds, <String>{'p2'});
      expect(cubit.state.total, 1);
      expect(cubit.state.errorMessage, contains('Could not delete 1 products'));
      expect(cubit.state.isDeletingSelected, isFalse);
    },
  );

  test('the search runs on the database and starts a new list', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.search('First');

    expect(repository.searches.last, 'First');
    expect(cubit.state.products, hasLength(1));
    expect(cubit.state.search, 'First');
  });

  test('a picture of a product is added and kept', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    final images = await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/one.png',
    );

    expect(images, hasLength(1));
    expect(images.first.imageUrl, 'https://example.com/one.png');
    // The first picture is the one the card shows.
    expect(images.first.isPrimary, isTrue);
    expect(cubit.state.products.first.imageUrl, 'https://example.com/one.png');
  });

  test('the primary picture of a product follows the chosen one', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/one.png',
    );
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/two.png',
    );

    final second = (await cubit.loadProductImages('p1')).last;
    final images = await cubit.setPrimaryProductImage(second);

    expect(images.where((image) => image.isPrimary), hasLength(1));
    expect(images.firstWhere((image) => image.isPrimary).id, second.id);
    // The card shows the picture the admin chose.
    expect(cubit.state.products.first.imageUrl, second.imageUrl);
  });

  test('a failing picture write leaves the pictures alone', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    repository.failingImageUrl = 'https://example.com/broken.png';
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(
      () => cubit.addProductImage(
        productId: 'p1',
        imageUrl: 'https://example.com/broken.png',
      ),
      throwsA(isA<AdminProductException>()),
    );
    expect(await cubit.loadProductImages('p1'), isEmpty);
  });

  test('the settings of a picture do not touch the other pictures', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/one.png',
    );
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/two.png',
    );

    final images = await cubit.loadProductImages('p1');
    await cubit.updateProductImageSettings(
      image: images.first,
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
    );

    final after = await cubit.loadProductImages('p1');
    // The picture that was changed keeps its new settings.
    expect(after.first.fit, BoxFit.contain);
    expect(after.first.alignment, Alignment.topLeft);
    // The other picture keeps the ones it had.
    expect(after.last.fit, BoxFit.fill);
    expect(after.last.alignment, Alignment.center);
    // The card shows the primary picture with the same settings.
    expect(cubit.state.products.first.imageFit, BoxFit.contain);
    expect(cubit.state.products.first.imageAlignment, Alignment.topLeft);
  });

  test('the settings can be applied to every picture of a product', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/one.png',
    );
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/two.png',
    );

    await cubit.applyProductImageSettings(
      productId: 'p1',
      fit: BoxFit.fill,
      alignment: Alignment.bottomRight,
    );

    final after = await cubit.loadProductImages('p1');
    expect(after, hasLength(2));
    for (final image in after) {
      expect(image.fit, BoxFit.fill);
      expect(image.alignment, Alignment.bottomRight);
    }
  });

  test('a failed write keeps the picture and its settings', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/one.png',
    );

    final before = await cubit.loadProductImages('p1');
    repository.failingImageUrl = 'https://example.com/two.png';

    await expectLater(
      cubit.updateProductImage(
        image: before.first,
        imageUrl: 'https://example.com/two.png',
      ),
      throwsA(isA<AdminProductException>()),
    );

    // The picture that was saved is still there with its old url.
    final after = await cubit.loadProductImages('p1');
    expect(after.first.imageUrl, 'https://example.com/one.png');
  });

  test('a picture of one product is not written to another', () async {
    final repository = _FakeProductRepository(
      products: const <AdminProduct>[_product],
    );
    final cubit = AdminProductCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.addProductImage(
      productId: 'p1',
      imageUrl: 'https://example.com/one.png',
    );

    expect(await cubit.loadProductImages('p2'), isEmpty);
  });
}
