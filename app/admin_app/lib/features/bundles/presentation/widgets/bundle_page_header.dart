import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_strings.dart';

import 'package:admin_app/shared/widgets/admin_bulk_selection_bar.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';

class BundlePageHeader extends StatelessWidget {
  const BundlePageHeader({
    super.key,
    required this.count,
    this.onAdd,
    this.selectedCount = 0,
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
    this.isDeletingSelected = false,
  });

  final int count;

  /// 020 يطلب `catalog.product.write` لكتابة الباقة، فالصفحة تُعرض للقارئ
  /// وأدوات الكتابة تُحجب عنه.
  final VoidCallback? onAdd;
  final int selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final bool isDeletingSelected;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: S.bundles,
      subtitle: S.bundlesCount(count),
      actions: [
        if (onAdd != null)
          AdminCreateButton(label: S.addBundle, onPressed: onAdd),
      ],
      footer: selectedCount > 0
          ? AdminBulkSelectionBar(
              selectedCount: selectedCount,
              totalCount: count,
              selectedLabel: S.selectedCountLabel(selectedCount),
              selectAllLabel: S.selectAllBundles(count),
              deleteLabel: S.deleteSelectedBundles,
              onSelectAll: onSelectAll,
              onClearSelection: onClearSelection,
              onDelete: onDeleteSelected,
              isDeletingSelected: isDeletingSelected,
            )
          : null,
    );
  }
}
