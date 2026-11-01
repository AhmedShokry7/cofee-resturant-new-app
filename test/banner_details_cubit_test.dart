import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/banner_details/banner_details_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// The banner page used to run these catalogue reads from inside its widget
/// state, with a setState at the end.
void main() {
  test('a product banner resolves its target', () async {
    final catalog = _FakeCatalog(product: _product('p1'));
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'p1',
      ),
    );
    await _settled(cubit);

    expect(cubit.state.targetProduct?.id, 'p1');
    expect(catalog.productReads, 1);
    await cubit.close();
  });

  test('a bundle banner resolves its target', () async {
    final catalog = _FakeCatalog(bundle: _bundle('u1'));
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.bundle,
        targetId: 'u1',
      ),
    );
    await _settled(cubit);

    expect(cubit.state.targetBundle?.id, 'u1');
    expect(catalog.bundleReads, 1);
    await cubit.close();
  });

  test('an already resolved banner costs no query', () async {
    final catalog = _FakeCatalog(product: _product('p1'));
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'p1',
        targetProduct: _product('p1'),
      ),
    );
    await _settled(cubit);

    expect(catalog.productReads, 0);
    await cubit.close();
  });

  test('a category or url banner reads nothing', () async {
    final catalog = _FakeCatalog(product: _product('p1'));
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.category,
        targetId: 'cat-1',
      ),
    );
    await _settled(cubit);

    expect(catalog.productReads, 0);
    expect(catalog.bundleReads, 0);
    await cubit.close();
  });

  test('a missing target leaves the banner as it was', () async {
    final catalog = _FakeCatalog();
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'gone',
      ),
    );
    await _settled(cubit);

    expect(cubit.state.targetProduct, isNull);
    expect(cubit.state.targetId, 'gone');
    await cubit.close();
  });

  test('a failing catalogue read is swallowed', () async {
    final catalog = _FakeCatalog(throwOnRead: true);
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'p1',
      ),
    );
    await _settled(cubit);

    expect(cubit.state.targetProduct, isNull);
    expect(cubit.state.id, 'b1');
    await cubit.close();
  });
}

Future<void> _settled(BannerDetailsCubit cubit) =>
    Future<void>.delayed(const Duration(milliseconds: 10));

ProductModel _product(String id) =>
    ProductModel(id: id, name: 'P', price: 10, image: '');

BundleModel _bundle(String id) =>
    BundleModel(id: id, title: 'B', productIds: const [], price: 20);

class _FakeCatalog implements CatalogRepository {
  _FakeCatalog({this.product, this.bundle, this.throwOnRead = false});

  final ProductModel? product;
  final BundleModel? bundle;
  final bool throwOnRead;

  int productReads = 0;
  int bundleReads = 0;

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    productReads++;
    if (throwOnRead) throw Exception('catalogue down');
    return product?.id == id ? product : null;
  }

  @override
  Future<BundleModel?> getBundleById(String id) async {
    bundleReads++;
    if (throwOnRead) throw Exception('catalogue down');
    return bundle?.id == id ? bundle : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
