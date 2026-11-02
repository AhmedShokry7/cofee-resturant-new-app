import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/data/model/banner_links.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/data/repositories/banner_link_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'banner_details_state.dart';

/// Owns the banner page: the banner it opened and the rows shown under it.
///
/// A banner from the list carries only the id of what it points at, so the page
/// used to run those catalogue reads from inside its widget state and finish
/// with a `setState`. The reads belong here.
///
/// The rows under the banner are read for the banner's own target as well. They
/// used to be picked out of the ten products home loaded, which meant a category
/// banner showed a slice of home rather than its category, and a category the
/// customer had not seen on home showed nothing.
///
/// Everything the admin linked to the banner beyond its single `target_id` is
/// appended to those rows, from the link tables migration 222 added.
class BannerDetailsCubit extends Cubit<BannerDetailsState> {
  BannerDetailsCubit({
    required this.repository,
    required BannerModel banner,
    this.branchId,
  }) : super(BannerDetailsState(banner: banner)) {
    ready = resolve();
  }

  /// Completes once the rows under the banner are in, or their reads failed.
  ///
  /// The constructor starts the work without a caller to await, so the page (and
  /// its tests) settles on this rather than on a guessed delay.
  late final Future<void> ready;

  final CatalogRepository repository;

  /// Branch whose prices the strip shows, so the page and home agree.
  final String? branchId;

  /// How many rows the strip asks for.
  ///
  /// The carousel shows ten and throws the rest away, so reading a whole
  /// category would pay for rows nobody scrolls to.
  static const int relatedLimit = 10;

  /// Resolves the target the caller did not carry, then the rows under it.
  ///
  /// A failure, or a row that no longer exists, leaves the page rendering the
  /// banner with an empty strip: a banner the admin unpublished between the list
  /// and the tap is a dead end, not a crash.
  Future<void> resolve() async {
    final banner = state.banner;
    final id = banner.targetId;
    // Every target that can be looked up is looked up by id, so a banner
    // without one has nowhere to read from.
    if (id == null) return;
    final own = await _readTarget(banner, id);
    if (isClosed) return;
    if (own != null) {
      emit(state.copyWith(banner: own.banner, related: own.rows));
    }

    // The link tables carry everything else the admin chose for this banner.
    // `target_id` holds one row, so a banner picked for three products and a
    // category could only ever show the one that was saved last.
    final links =
        (await _read(() => readBannerLinks(repository, id))) ??
        BannerLinks.none;
    if (isClosed || links.isEmpty) return;
    final extra = await _read(() => _linkedProducts(links));
    if (isClosed) return;
    emit(state.copyWith(related: _deduped(state.related, extra ?? const [])));
  }

  /// The rows behind the banner's own target, or null when nothing was read.
  Future<({BannerModel? banner, List<ProductModel> rows})?> _readTarget(
    BannerModel banner,
    String id,
  ) async {
    switch (banner.target) {
      case BannerTarget.product:
        final carried = banner.targetProduct;
        final product =
            carried ??
            await _read(() => repository.getById(id, branchId: branchId));
        if (product == null) return null;
        return (
          banner: carried == null
              ? banner.copyWith(targetProduct: product)
              : banner,
          rows: [product],
        );
      case BannerTarget.bundle:
        final carried = banner.targetBundle;
        final bundle =
            carried ?? await _read(() => repository.getBundleById(id));
        if (bundle == null) return null;
        final components = await _read(
          () => getProductsByIds(
            repository,
            bundle.components.map((c) => c.productId).toList(),
            branchId: branchId,
          ),
        );
        return (
          banner: carried == null
              ? banner.copyWith(targetBundle: bundle)
              : banner,
          rows: components ?? const [],
        );
      case BannerTarget.category:
        final products = await _read(
          () => repository.getProducts(
            branchId: branchId,
            categoryId: id,
            limit: relatedLimit,
          ),
        );
        if (products == null) return null;
        return (banner: null, rows: products);
      case BannerTarget.url:
      case BannerTarget.none:
        return null;
    }
  }

  /// The products linked to the banner: the chosen rows first, then every
  /// product of each chosen category, both in the order the admin set.
  Future<List<ProductModel>> _linkedProducts(BannerLinks links) async {
    final chosen = await getProductsByIds(
      repository,
      links.productIds,
      branchId: branchId,
    );
    final perCategory = await Future.wait(
      links.categoryIds.map(
        (categoryId) => repository.getProducts(
          branchId: branchId,
          categoryId: categoryId,
          limit: relatedLimit,
        ),
      ),
    );
    return [...chosen, for (final rows in perCategory) ...rows];
  }

  /// The rows already on screen, then [extra] with anything shown twice
  /// dropped: a product that is both linked and inside a linked category is
  /// one card, not two.
  static List<ProductModel> _deduped(
    List<ProductModel> first,
    List<ProductModel> extra,
  ) {
    final seen = first.map((product) => product.id).toSet();
    return [
      ...first,
      for (final product in extra)
        if (seen.add(product.id)) product,
    ];
  }

  Future<T?> _read<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return null;
    }
  }
}
