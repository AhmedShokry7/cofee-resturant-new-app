import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/home/data/model/banner_links.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/data/repositories/banner_link_repository.dart';
import 'package:new_coffee/features/home/presentation/manager/banner_details/banner_details_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// What the banner page shows under the banner.
///
/// These reads used to run from inside the widget state with a `setState` at the
/// end, and the rows themselves came out of the ten products home had loaded -
/// so a category banner showed a slice of home, and a category home had not
/// shown showed nothing.
void main() {
  ProductModel product(String id, {String? categoryId}) => ProductModel(
    id: id,
    name: 'P$id',
    price: 10,
    image: '',
    categoryId: categoryId,
  );

  test('a product banner resolves its target and shows it', () async {
    final catalog = _FakeCatalog(products: [product('p1')]);
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'p1',
      ),
    );
    await cubit.ready;

    expect(cubit.state.banner.targetProduct?.id, 'p1');
    expect(cubit.state.related.map((p) => p.id), ['p1']);
    expect(catalog.idReads, 1);
    await cubit.close();
  });

  test('a bundle banner lists the components it resolved', () async {
    final catalog = _FakeCatalog(
      products: [product('a')],
      bundle: BundleModel(
        id: 'u1',
        productIds: const ['a', 'z'],
        price: 20,
        components: const [
          BundleComponent(productId: 'a', quantity: 1),
          BundleComponent(productId: 'z', quantity: 1),
        ],
      ),
    );
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.bundle,
        targetId: 'u1',
      ),
    );
    await cubit.ready;

    expect(cubit.state.banner.targetBundle?.id, 'u1');
    expect(cubit.state.related.map((p) => p.id), [
      'a',
    ], reason: 'a component the catalogue did not return is skipped');
    expect(catalog.bundleReads, 1);
    await cubit.close();
  });

  test('a category banner reads its own category', () async {
    final catalog = _FakeCatalog(
      products: [
        product('a', categoryId: 'cat-1'),
        product('b', categoryId: 'cat-2'),
      ],
    );
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.category,
        targetId: 'cat-1',
      ),
    );
    await cubit.ready;

    expect(
      catalog.lastCategoryId,
      'cat-1',
      reason: 'matched on the category id, not on a label',
    );
    expect(
      catalog.lastLimit,
      BannerDetailsCubit.relatedLimit,
      reason: 'the strip is one screen of cards, not the whole category',
    );
    expect(cubit.state.related.map((p) => p.id), ['a']);
    await cubit.close();
  });

  test('an already resolved target costs no lookup', () async {
    final catalog = _FakeCatalog(products: [product('p1')]);
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.product,
        targetId: 'p1',
        targetProduct: product('p1'),
      ),
    );
    await cubit.ready;

    expect(
      catalog.idReads,
      0,
      reason: 'the caller carried the row, so it is not read again',
    );
    expect(cubit.state.related.map((p) => p.id), ['p1']);
    await cubit.close();
  });

  test('a url or target-less banner reads nothing', () async {
    final catalog = _FakeCatalog(products: [product('p1')]);
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.url,
        targetUrl: 'https://example.com',
      ),
    );
    await cubit.ready;

    expect(catalog.reads, 0);
    expect(cubit.state.related, isEmpty);
    await cubit.close();
  });

  test('a banner without an id reads nothing', () async {
    final catalog = _FakeCatalog(products: [product('p1')]);
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(id: 'b1', image: ''),
    );
    await cubit.ready;

    expect(catalog.reads, 0);
    expect(cubit.state.banner.target, BannerTarget.category);
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
    await cubit.ready;

    expect(cubit.state.banner.targetProduct, isNull);
    expect(cubit.state.banner.targetId, 'gone');
    expect(cubit.state.related, isEmpty);
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
    await cubit.ready;

    expect(cubit.state.banner.targetProduct, isNull);
    expect(cubit.state.banner.id, 'b1');
    await cubit.close();
  });

  test('the rows linked to the banner join the strip', () async {
    // The banner points at cat-1, and the admin also picked p9 and cat-2 for
    // it. Before the link tables existed, `banners.target_id` could hold only
    // one of those, so the other two were dropped on save and never appeared.
    final catalog = _LinkCatalog(
      products: [
        product('a', categoryId: 'cat-1'),
        product('b', categoryId: 'cat-2'),
        product('p9'),
      ],
      links: const BannerLinks(productIds: ['p9'], categoryIds: ['cat-2']),
    );
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.category,
        targetId: 'cat-1',
      ),
    );
    await cubit.ready;

    expect(cubit.state.related.map((p) => p.id), ['a', 'p9', 'b']);
    await cubit.close();
  });

  test(
    'a product both linked and inside a linked category shows once',
    () async {
      final catalog = _LinkCatalog(
        products: [
          product('a', categoryId: 'cat-1'),
          product('b', categoryId: 'cat-2'),
        ],
        links: const BannerLinks(productIds: ['b'], categoryIds: ['cat-2']),
      );
      final cubit = BannerDetailsCubit(
        repository: catalog,
        banner: BannerModel(
          id: 'b1',
          image: '',
          target: BannerTarget.category,
          targetId: 'cat-1',
        ),
      );
      await cubit.ready;

      expect(cubit.state.related.map((p) => p.id), ['a', 'b']);
      await cubit.close();
    },
  );

  test('a catalogue with no link tables shows the target alone', () async {
    // The database migration may not be applied yet. The page then behaves
    // exactly as it did before the link tables existed, rather than opening on
    // an error or an empty strip.
    final catalog = _FakeCatalog(products: [product('a', categoryId: 'cat-1')]);
    final cubit = BannerDetailsCubit(
      repository: catalog,
      banner: BannerModel(
        id: 'b1',
        image: '',
        target: BannerTarget.category,
        targetId: 'cat-1',
      ),
    );
    await cubit.ready;

    expect(cubit.state.related.map((p) => p.id), ['a']);
    await cubit.close();
  });
}

class _FakeCatalog implements CatalogRepository {
  _FakeCatalog({
    this.products = const [],
    this.bundle,
    this.throwOnRead = false,
  });

  /// The rows this catalogue holds; [getById] and [getProducts] answer from them.
  final List<ProductModel> products;
  final BundleModel? bundle;
  final bool throwOnRead;

  int idReads = 0;
  int bundleReads = 0;
  int categoryReads = 0;

  String? lastCategoryId;
  int? lastLimit;

  int get reads => idReads + bundleReads + categoryReads;

  void _failIfAsked() {
    if (throwOnRead) throw Exception('catalogue down');
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    idReads++;
    _failIfAsked();
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) async {
    categoryReads++;
    lastCategoryId = categoryId;
    lastLimit = limit;
    _failIfAsked();
    return products
        .where((p) => p.categoryId == categoryId)
        .take(limit)
        .toList();
  }

  @override
  Future<BundleModel?> getBundleById(String id) async {
    bundleReads++;
    _failIfAsked();
    return bundle?.id == id ? bundle : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A catalogue that also keeps the link tables of migration 222.
class _LinkCatalog extends _FakeCatalog implements BannerLinkRepository {
  _LinkCatalog({super.products, this.links = BannerLinks.none});

  final BannerLinks links;

  int linkReads = 0;

  @override
  Future<BannerLinks> getBannerLinks(String bannerId) async {
    linkReads++;
    return links;
  }
}
