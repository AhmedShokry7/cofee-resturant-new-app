import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_state.dart';

/// The strip under the grid of the products: the spinner while more pages
/// arrive, the message when nothing matches, or the button that asks for
/// the next page.
class ProductPageFooter extends StatelessWidget {
  const ProductPageFooter({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
  });

  final AdminProductState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == AdminProductStatus.failure) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                state.errorMessage ?? S.couldNotLoadProducts,
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(S.retry)),
          ],
        ),
      );
    }
    if (state.status == AdminProductStatus.loading && !state.hasProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasProducts) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
        child: Text(
          state.search.trim().isEmpty ? S.noProductsYet : S.noProductsFound,
          textAlign: TextAlign.center,
        ),
      );
    }
    if (state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
        child: Center(
          child: TextButton(onPressed: onLoadMore, child: Text(S.more)),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
