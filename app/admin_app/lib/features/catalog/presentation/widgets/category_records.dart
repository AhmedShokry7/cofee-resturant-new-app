import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/category_card.dart';

/// The categories whose name or description holds [search].
List<AdminCategory> filterCategories(
  List<AdminCategory> categories,
  String search,
) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return categories;
  return categories
      .where(
        (c) =>
            c.nameAr.toLowerCase().contains(q) ||
            c.nameEn.toLowerCase().contains(q) ||
            (c.descriptionAr?.toLowerCase().contains(q) ?? false) ||
            (c.descriptionEn?.toLowerCase().contains(q) ?? false),
      )
      .toList(growable: false);
}

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

        final cardWidth = (width - (columns - 1) * AppSpacing.md) / columns;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: cardWidth / (cardWidth + 100),
          ),
          itemCount: categories.length,
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
      },
    );
  }
}
