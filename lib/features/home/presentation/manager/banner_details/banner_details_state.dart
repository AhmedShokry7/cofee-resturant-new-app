part of 'banner_details_cubit.dart';

/// What the banner page shows: the banner itself and the rows under it.
@immutable
class BannerDetailsState {
  const BannerDetailsState({required this.banner, this.related = const []});

  final BannerModel banner;

  /// The products the strip under the banner shows.
  ///
  /// Read from the catalogue for the banner's own target, not borrowed from the
  /// ten rows home happened to load: a category banner used to show whichever of
  /// those matched and nothing at all when none of them did.
  final List<ProductModel> related;

  BannerDetailsState copyWith({
    BannerModel? banner,
    List<ProductModel>? related,
  }) => BannerDetailsState(
    banner: banner ?? this.banner,
    related: related ?? this.related,
  );
}
