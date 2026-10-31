import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_page_header.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_records.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

/// The header and the list of the bundles, the whole content of the page.
///
/// أدوات الكتابة اختيارية كلها: من لا يملك `catalog.product.write` تُعرض له
/// الباقات قراءةً فقط لأن قاعدته ترفض كل كتابة منها.
class BundlePageBody extends StatelessWidget {
  const BundlePageBody({
    super.key,
    required this.bundles,
    required this.search,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.selectedIds = const <String>{},
    this.isDeletingSelected = false,
    this.onSelect,
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
  });

  final List<AdminBundle> bundles;
  final String search;
  final VoidCallback? onAdd;
  final ValueChanged<AdminBundle>? onEdit;
  final ValueChanged<AdminBundle>? onDelete;
  final ValueChanged<AdminBundle>? onToggleActive;
  final ValueChanged<AdminBundle>? onChangeImage;
  final Set<String> selectedIds;
  final bool isDeletingSelected;
  final ValueChanged<AdminBundle>? onSelect;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BundlePageHeader(
            count: filterBundles(bundles, search).length,
            onAdd: onAdd,
            selectedCount: selectedIds.length,
            onSelectAll: onSelectAll,
            onClearSelection: onClearSelection,
            onDeleteSelected: onDeleteSelected,
            isDeletingSelected: isDeletingSelected,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: BundleRecords(
              bundles: bundles,
              search: search,
              selectedIds: selectedIds,
              onSelect: onSelect,
              onEdit: onEdit,
              onDelete: onDelete,
              onToggleActive: onToggleActive,
              onChangeImage: onChangeImage,
            ),
          ),
        ],
      ),
    );
  }
}
