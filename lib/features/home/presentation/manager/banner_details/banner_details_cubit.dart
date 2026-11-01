import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Owns the banner shown by the banner detail page.
///
/// A banner from the list carries only the id of what it points at, so the
/// page used to query the catalogue itself from inside its widget state. The
/// lookup belongs here.
class BannerDetailsCubit extends Cubit<BannerModel> {
  BannerDetailsCubit({
    required this.repository,
    required BannerModel banner,
  }) : super(banner) {
    resolveTarget();
  }

  final CatalogRepository repository;

  /// Loads the product or bundle behind the banner when the caller did not
  /// already carry it.
  ///
  /// A failure, or a row that no longer exists, leaves the banner untouched:
  /// the page still renders and only the button keeps its old no-op behaviour.
  Future<void> resolveTarget() async {
    final id = state.targetId;
    if (id == null) return;
    final missing = switch (state.target) {
      BannerTarget.product => state.targetProduct == null,
      BannerTarget.bundle => state.targetBundle == null,
      _ => false,
    };
    if (!missing) return;
    try {
      if (state.target == BannerTarget.product) {
        final product = await repository.getById(id);
        if (isClosed || product == null) return;
        emit(state.copyWith(targetProduct: product));
      } else {
        final bundle = await repository.getBundleById(id);
        if (isClosed || bundle == null) return;
        emit(state.copyWith(targetBundle: bundle));
      }
    } catch (_) {
      // Navigation degrades gracefully; nothing to tell the customer about.
    }
  }
}
