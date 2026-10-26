import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_records.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';

/// The bundles whose name or description holds [search].
List<AdminBundle> filterBundles(List<AdminBundle> bundles, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return bundles;
  return bundles
      .where(
        (b) =>
            b.nameAr.toLowerCase().contains(q) ||
            b.nameEn.toLowerCase().contains(q) ||
            (b.descriptionAr?.toLowerCase().contains(q) ?? false) ||
            (b.descriptionEn?.toLowerCase().contains(q) ?? false),
      )
      .toList(growable: false);
}

/// The grid of bundle cards.
///
/// Bundles share the exact card of the categories, so the catalogue keeps
/// one card instead of two copies of the same layout.
class BundleRecords extends StatelessWidget {
  const BundleRecords({
    super.key,
    required this.bundles,
    this.search = '',
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.selectedIds = const <String>{},
    this.onSelect,
  });

  /// Every loaded bundle; the list filters them with [search].
  final List<AdminBundle> bundles;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminBundle>? onEdit;
  final ValueChanged<AdminBundle>? onDelete;
  final ValueChanged<AdminBundle>? onToggleActive;
  final ValueChanged<AdminBundle>? onChangeImage;

  /// The bundles that are picked for a bulk action.
  final Set<String> selectedIds;

  final ValueChanged<AdminBundle>? onSelect;

  List<AdminBundle> get _filtered => filterBundles(bundles, search);

  @override
  Widget build(BuildContext context) {
    final bundles = _filtered;
    if (bundles.isEmpty) {
      final filtering = search.trim().isNotEmpty;
      return AdminEmptyState(
        icon: filtering
            ? HugeIcons.strokeRoundedSearch01
            : HugeIcons.strokeRoundedPackage,
        message: filtering ? S.noBundlesFound : S.noBundlesYet,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns;
        if (width > 1400) {
          columns = 5;
        } else if (width > 1100) {
          columns = 4;
        } else if (width > 800) {
          columns = 3;
        } else if (width > 500) {
          columns = 2;
        } else {
          columns = 1;
        }

        final cardWidth = (width - (columns - 1) * AppDimensions.md) / columns;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppDimensions.md,
            mainAxisSpacing: AppDimensions.md,
            childAspectRatio: cardWidth / (cardWidth + 100),
          ),
          itemCount: bundles.length,
          itemBuilder: (context, index) {
            final bundle = bundles[index];
            return CategoryCard(
              category: AdminCategory(
                id: bundle.id,
                nameAr: bundle.nameAr,
                nameEn: bundle.nameEn,
                descriptionAr: bundle.descriptionAr,
                descriptionEn: bundle.descriptionEn,
                isActive: bundle.isActive,
                imageUrl: bundle.imageUrl,
                productCount: bundle.components.length,
              ),
              countLabel: S.bundleComponentsCount(bundle.components.length),
              onEdit: onEdit == null ? null : () => onEdit!(bundle),
              onDelete: onDelete == null ? null : () => onDelete!(bundle),
              onToggleActive: onToggleActive == null
                  ? null
                  : () => onToggleActive!(bundle),
              onChangeImage: onChangeImage == null
                  ? null
                  : () => onChangeImage!(bundle),
              isSelected: selectedIds.contains(bundle.id),
              onSelect: onSelect == null ? null : () => onSelect!(bundle),
            );
          },
        );
      },
    );
  }
}
