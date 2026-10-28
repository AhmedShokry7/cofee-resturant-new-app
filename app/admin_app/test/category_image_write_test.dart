import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_cubit.dart';

/// The picture url the stand-in bucket answers with.
const String _uploadedUrl =
    'https://project.supabase.co/storage/v1/object/public/'
    'product-images/products/category-c1/1_ab.jpg';

/// The catalogue as the category screen needs it, with the writes counted.
///
/// The row of a category is written by the upload itself, exactly as the real
/// repository does it, so the test can count how many times a picture reaches
/// the database.
class _FakeCatalogRepository extends AdminProductRepository {
  _FakeCatalogRepository({this.categories = const <AdminCategory>[]});

  final List<AdminCategory> categories;

  /// Every write of the row of a category, in the order it happened.
  final List<String?> rowWrites = <String?>[];

  /// Every file the bucket took.
  final List<String> bucketUploads = <String>[];

  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    return AdminCatalogSnapshot(
      products: const <Never>[],
      categories: categories,
    );
  }

  @override
  Future<void> updateCategoryImage(String categoryId, String? imageUrl) async {
    rowWrites.add(imageUrl);
  }

  @override
  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    bucketUploads.add(_uploadedUrl);
    await updateCategoryImage(categoryId, _uploadedUrl);
    return _uploadedUrl;
  }
}

void main() {
  const categories = <AdminCategory>[
    AdminCategory(id: 'c1', nameAr: 'قهوة', nameEn: 'Coffee'),
  ];

  test('a picture uploaded to the bucket writes the row once', () async {
    final repository = _FakeCatalogRepository(categories: categories);
    final cubit = AdminCategoryCubit(repository: repository);
    await cubit.load();

    final url = await cubit.uploadCategoryImage(
      categoryId: 'c1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'cup.jpg',
      contentType: 'image/jpeg',
    );

    expect(url, _uploadedUrl);
    expect(repository.bucketUploads, hasLength(1));
    expect(repository.rowWrites, <String>[_uploadedUrl]);
    expect(cubit.state.categories.single.imageUrl, _uploadedUrl);
    await cubit.close();
  });

  test('a linked picture writes the row once and shows in the list', () async {
    final repository = _FakeCatalogRepository(categories: categories);
    final cubit = AdminCategoryCubit(repository: repository);
    await cubit.load();

    const link = 'https://cdn.example/tea.png';
    final written = await cubit.updateCategoryImage('c1', link);

    expect(written, link);
    expect(repository.rowWrites, <String>[link]);
    expect(cubit.state.categories.single.imageUrl, link);
    await cubit.close();
  });

  test('removing the picture of a category clears it from the list', () async {
    final repository = _FakeCatalogRepository(
      categories: const <AdminCategory>[
        AdminCategory(
          id: 'c1',
          nameAr: 'قهوة',
          nameEn: 'Coffee',
          imageUrl: 'https://cdn.example/old.png',
        ),
      ],
    );
    final cubit = AdminCategoryCubit(repository: repository);
    await cubit.load();

    await cubit.updateCategoryImage('c1', null);

    expect(repository.rowWrites, <String?>[null]);
    expect(cubit.state.categories.single.imageUrl, isNull);
    await cubit.close();
  });
}
