import 'package:new_coffee/features/home/data/model/banner_links.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Optional capability: read the extra products and categories a banner
/// promotes, which the single `banners.target_id` column cannot hold.
abstract interface class BannerLinkRepository {
  Future<BannerLinks> getBannerLinks(String bannerId);
}

/// Reads the links when the repository keeps them, and returns none when it
/// does not.
///
/// Two ordinary situations mean "none": a local or test catalogue, and a
/// database where migration 222 has not been applied yet. In both the banner
/// page still shows the row behind `target_id`, which is the whole behaviour it
/// had before the link tables existed. A read that fails for any other reason
/// is left to propagate, so the caller's own error handling sees it.
Future<BannerLinks> readBannerLinks(
  CatalogRepository repository,
  String bannerId,
) async {
  if (repository case final BannerLinkRepository linkRepository) {
    return linkRepository.getBannerLinks(bannerId);
  }
  return BannerLinks.none;
}
