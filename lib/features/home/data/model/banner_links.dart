import 'package:flutter/foundation.dart';

/// What a banner promotes besides the one row in `banners.target_id`.
///
/// Migration 222 added `marketing.banner_products` and
/// `marketing.banner_categories` because a banner row can carry a single
/// target, so every product or category the admin picked after the first one
/// had nowhere to be stored and never reached the banner page.
@immutable
class BannerLinks {
  const BannerLinks({this.productIds = const [], this.categoryIds = const []});

  /// Products chosen for this banner, in the order the admin set.
  final List<String> productIds;

  /// Categories chosen for this banner; every product of each one joins the
  /// strip under the banner.
  final List<String> categoryIds;

  bool get isEmpty => productIds.isEmpty && categoryIds.isEmpty;

  static const BannerLinks none = BannerLinks();

  /// Reads the two link queries into one value.
  ///
  /// The columns are the only ones the bridge views expose, and a missing link
  /// table is not a failure here: the caller passes empty lists when migration
  /// 222 has not been applied yet.
  factory BannerLinks.fromRows({
    List<Map<String, dynamic>> productRows = const [],
    List<Map<String, dynamic>> categoryRows = const [],
  }) => BannerLinks(
    productIds: _ids(productRows, 'product_id'),
    categoryIds: _ids(categoryRows, 'category_id'),
  );

  static List<String> _ids(List<Map<String, dynamic>> rows, String column) =>
      rows
          .map((r) => r[column])
          .whereType<Object>()
          .map((v) => v.toString())
          .toList(growable: false);
}
