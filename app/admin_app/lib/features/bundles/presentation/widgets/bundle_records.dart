import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/text_search.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_record_grid.dart';
import 'package:admin_app/shared/widgets/category_card.dart';

/// The bundles whose name or description holds [search].
List<AdminBundle> filterBundles(List<AdminBundle> bundles, String search) => [
  for (final bundle in bundles)
    if (matchesSearchText(
      query: search,
      nameAr: bundle.nameAr,
      nameEn: bundle.nameEn,
      descriptionAr: bundle.descriptionAr,
      descriptionEn: bundle.descriptionEn,
    ))
      bundle,
];

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
        icon: filtering ? AppIcons.search01 : AppIcons.package,
        message: filtering ? S.noBundlesFound : S.noBundlesYet,
      );
    }

    return AdminRecordGrid(
      itemCount: bundles.length,
      cardExtent: (cardWidth) =>
          CategoryCard.extent(cardWidth, MediaQuery.textScalerOf(context)),
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
  }
}
