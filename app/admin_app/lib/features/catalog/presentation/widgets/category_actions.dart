import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_cubit.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// The dialog that creates or edits a category; it writes through the cubit
/// of the page and closes itself when the write succeeded.
Future<void> showCategoryDataDialog({
  required BuildContext context,
  required AdminCategoryCubit cubit,
  AdminCategory? initialCategory,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) => CategoryDataDialog(
      initialCategory: initialCategory,
      onSave: (nameAr, nameEn, descriptionAr, descriptionEn) async {
        try {
          final AdminCategory category;
          if (initialCategory == null) {
            category = await cubit.createCategory(
              nameAr: nameAr,
              nameEn: nameEn,
              descriptionAr: descriptionAr,
              descriptionEn: descriptionEn,
            );
          } else {
            category = await cubit.updateCategory(
              categoryId: initialCategory.id,
              nameAr: nameAr,
              nameEn: nameEn,
              descriptionAr: descriptionAr,
              descriptionEn: descriptionEn,
            );
          }
          if (!context.mounted) return;
          Navigator.of(context).pop(category);
        } catch (error) {
          messenger.showSnackBar(SnackBar(content: Text('$error')));
        }
      },
    ),
  );
}

/// Opens the dialog that replaces or removes the picture of a category.
Future<void> showCategoryImageDialog({
  required BuildContext context,
  required AdminCategoryCubit cubit,
  required AdminCategory category,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => CategoryImageDialog(
      currentImageUrl: category.imageUrl,
      onApply: (source) async {
        if (source.isLink) {
          await cubit.updateCategoryImage(category.id, source.url);
        } else {
          await cubit.uploadCategoryImage(
            categoryId: category.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
      },
      onRemove: () async {
        await cubit.deleteCategoryImageFile(category.imageUrl);
        await cubit.updateCategoryImage(category.id, null);
      },
    ),
  );
}

/// Asks the admin to confirm the deletion of a category, then deletes it.
void confirmDeleteCategory(
  BuildContext context,
  AdminCategoryCubit cubit,
  AdminCategory category,
) {
  showConfirmDeleteSnackBar(
    context,
    message: S.deleteCategoryConfirm(category.nameAr),
    onConfirm: () async {
      try {
        await cubit.deleteCategory(category.id);
      } catch (error) {
        if (!context.mounted) return;
        showErrorSnackBar(context, S.couldNotDeleteCategory('$error'));
      }
    },
  );
}

/// Asks the admin to confirm deleting every selected category.
Future<void> confirmDeleteSelectedCategories(
  BuildContext context,
  AdminCategoryCubit cubit,
) {
  final count = cubit.state.selectedCount;
  if (count == 0) return Future<void>.value();
  return confirmBulkDelete(
    context,
    title: S.deleteSelectedCategories,
    message: S.deleteCategoriesConfirm(count),
    onDelete: cubit.deleteSelected,
    deletedMessage: S.categoriesDeleted,
    partialMessage: S.categoriesDeletePartial,
  );
}

/// Activates or deactivates a category, and reports a failure to the admin.
Future<void> toggleCategoryActive(
  BuildContext context,
  AdminCategoryCubit cubit,
  AdminCategory category,
) async {
  try {
    await cubit.toggleActive(category);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(context, S.couldNotUpdateCategory('$error'));
  }
}
