import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/text_search.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_record_grid.dart';
import 'package:admin_app/shared/widgets/category_card.dart';

/// The categories whose name or description holds [search].
List<AdminCategory> filterCategories(
  List<AdminCategory> categories,
  String search,
) => [
  for (final category in categories)
    if (matchesSearchText(
      query: search,
      nameAr: category.nameAr,
      nameEn: category.nameEn,
      descriptionAr: category.descriptionAr,
      descriptionEn: category.descriptionEn,
    ))
      category,
];

/// The grid of category cards.
class CategoryRecords extends StatelessWidget {
  const CategoryRecords({
    super.key,
    required this.categories,
    this.search = '',
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.selectedIds = const <String>{},
    this.onSelect,
  });

  /// Every loaded category; the grid filters them with [search].
  final List<AdminCategory> categories;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminCategory>? onEdit;
  final ValueChanged<AdminCategory>? onDelete;
  final ValueChanged<AdminCategory>? onToggleActive;
  final ValueChanged<AdminCategory>? onChangeImage;

  /// The categories that are picked for a bulk action.
  final Set<String> selectedIds;

  final ValueChanged<AdminCategory>? onSelect;

  @override
  Widget build(BuildContext context) {
    final categories = filterCategories(this.categories, search);
    if (categories.isEmpty) {
      final filtering = search.trim().isNotEmpty;
      return AdminEmptyState(
        icon: filtering ? AppIcons.search01 : AppIcons.folder01,
        message: filtering ? S.noCategoriesFound : S.noCategoriesYet,
      );
    }

    return AdminRecordGrid(
      itemCount: categories.length,
      cardExtent: (cardWidth) =>
          CategoryCard.extent(cardWidth, MediaQuery.textScalerOf(context)),
      itemBuilder: (context, index) {
        final category = categories[index];
        return CategoryCard(
          category: category,
          onEdit: onEdit == null ? null : () => onEdit!(category),
          onDelete: onDelete == null ? null : () => onDelete!(category),
          onToggleActive: onToggleActive == null
              ? null
              : () => onToggleActive!(category),
          onChangeImage: onChangeImage == null
              ? null
              : () => onChangeImage!(category),
          isSelected: selectedIds.contains(category.id),
          onSelect: onSelect == null ? null : () => onSelect!(category),
        );
      },
    );
  }
}
