import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/navigation/admin_product_options_host.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_excel_controller.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_state.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_excel_actions.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_actions.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_footer.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_header.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_records.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

/// The products grid, its header and the messages of the cubit.
class ProductPageBody extends StatelessWidget {
  const ProductPageBody({
    super.key,
    required this.products,
    this.onAdd,
    this.total,
    this.categories = const <AdminCategory>[],
    this.onPickFile,
    this.onDownloadSample,
    this.onExport,
    this.onToggleFeatured,
    this.onDelete,
    this.onSave,
    this.onOpenImages,
    this.onOpenOptions,
    this.onSelect,
    this.selectedIds = const <String>{},
    this.onSelectAll,
    this.onClearSelection,
    this.onDeleteSelected,
    this.isSelectingAll = false,
    this.isDeletingSelected = false,
    this.onCreateCategory,
    this.savingProductId,
    this.importProgress,
    this.exportProgress,
    this.footer,
  });

  final List<AdminProduct> products;
  final VoidCallback? onAdd;
  final int? total;
  final List<AdminCategory> categories;
  final VoidCallback? onPickFile;
  final VoidCallback? onDownloadSample;
  final VoidCallback? onExport;
  final ValueChanged<AdminProduct>? onToggleFeatured;
  final ValueChanged<AdminProduct>? onDelete;
  final ValueChanged<AdminProduct>? onSave;
  final ValueChanged<AdminProduct>? onOpenImages;
  final ValueChanged<AdminProduct>? onOpenOptions;
  final ValueChanged<AdminProduct>? onSelect;
  final Set<String> selectedIds;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onDeleteSelected;
  final bool isSelectingAll;
  final bool isDeletingSelected;
  final Future<AdminCategory?> Function(
    String nameAr,
    String nameEn, [
    String? descriptionAr,
    String? descriptionEn,
  ])?
  onCreateCategory;
  final String? savingProductId;
  final double? importProgress;
  final double? exportProgress;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductPageHeader(
              count: total ?? products.length,
              selectedCount: selectedIds.length,
              isSelectingAll: isSelectingAll,
              isDeletingSelected: isDeletingSelected,
              onSelectAll: onSelectAll,
              onClearSelection: onClearSelection,
              onDeleteSelected: onDeleteSelected,
              onAdd: onAdd,
              onPickFile: onPickFile,
              onDownloadSample: onDownloadSample,
              onExport: onExport,
              importProgress: importProgress,
              exportProgress: exportProgress,
            ),
            const SizedBox(height: AppSpacing.lg),
            ProductRecords(
              products: products,
              categories: categories,
              savingProductId: savingProductId,
              onCreateCategory: onCreateCategory,
              onToggleFeatured: onToggleFeatured,
              onDelete: onDelete,
              onSave: onSave,
              onOpenImages: onOpenImages,
              onOpenOptions: onOpenOptions,
              onSelect: onSelect,
              selectedIds: selectedIds,
              footer: footer,
            ),
          ],
        ),
      ),
    );
  }
}

/// The products grid, its header and the messages of the cubit.
///
/// The view reads the state of [cubit], shows what it asks for and keeps the
/// footer while the catalogue is being scrolled to its end.
///
/// [canManage] is `catalog.product.write`: 117 refuses every product write
/// without it, so the write controls are not shown instead of always failing.
/// [canManageCategories] is the separate `catalog.category.write` that the
/// inline "new category" inside the product dialog needs.
class ProductPageView extends StatelessWidget {
  const ProductPageView({
    super.key,
    required this.cubit,
    required this.excel,
    required this.canManage,
    this.canManageCategories = false,
    this.importProgress,
    this.exportProgress,
  });

  final AdminProductCubit cubit;
  final ProductExcelController excel;
  final bool canManage;
  final bool canManageCategories;
  final double? importProgress;
  final double? exportProgress;

  @override
  Widget build(BuildContext context) {
    // حوار الأحجام ملك فيتشر المجموعات، فلا تفتحه الشاشة بنفسها: القشرة
    // تعير يدها، ومن لا قشرة فوقه لا يعرض العنصر.
    final openOptions = AdminProductOptionsHost.maybeOf(context);
    return BlocProvider<AdminProductCubit>.value(
      value: cubit,
      child: BlocConsumer<AdminProductCubit, AdminProductState>(
        listener: (context, state) => _onState(context, state),
        builder: (context, state) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) cubit.loadMore();
              return false;
            },
            child: ProductPageBody(
              products: state.products,
              selectedIds: canManage ? state.selectedIds : const <String>{},
              isSelectingAll: state.isSelectingAll,
              isDeletingSelected: state.isDeletingSelected,
              onSelectAll: canManage ? cubit.selectAllProducts : null,
              onClearSelection: canManage ? cubit.clearSelection : null,
              onDeleteSelected: canManage
                  ? () => _confirmDeleteSelected(context, cubit)
                  : null,
              total: state.total,
              categories: state.categories,
              savingProductId: state.savingProductId,
              onAdd: canManage
                  ? () => showProductDataDialog(
                      context: context,
                      cubit: cubit,
                      categories: state.categories,
                    )
                  : null,
              onSave: canManage
                  ? (product) =>
                        cubit.saveProduct(product).catchError((Object _) {})
                  : null,
              onToggleFeatured: canManage ? cubit.toggleFeatured : null,
              onDelete: canManage
                  ? (product) => cubit.deleteProduct(product.id)
                  : null,
              onOpenImages: canManage
                  ? (product) => showProductImagesDialog(
                      context: context,
                      cubit: cubit,
                      product: product,
                    )
                  : null,
              onOpenOptions: canManage ? openOptions : null,
              onSelect: canManage
                  ? (product) => cubit.toggleSelection(product.id)
                  : null,
              onCreateCategory: canManageCategories
                  ? (nameAr, nameEn, [descAr, descEn]) => cubit.createCategory(
                      nameAr: nameAr,
                      nameEn: nameEn,
                      descriptionAr: descAr,
                      descriptionEn: descEn,
                    )
                  : null,
              onPickFile: canManage
                  ? () => runProductImport(context, excel)
                  : null,
              onDownloadSample: () => runProductSampleDownload(context, excel),
              onExport: () => runProductExport(context, excel),
              importProgress: importProgress,
              exportProgress: exportProgress,
              footer: ProductPageFooter(
                state: state,
                onRetry: () => cubit.load(search: state.search),
                onLoadMore: cubit.loadMore,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteSelected(
    BuildContext context,
    AdminProductCubit cubit,
  ) async {
    final count = cubit.state.selectedCount;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.deleteSelectedProducts),
        content: Text(S.deleteProductsConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.errorColor,
              foregroundColor: AppColor.whiteColor,
            ),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.deleteSelectedProducts();
  }

  /// Shows the notice or the failure of the last action of the cubit.
  void _onState(BuildContext context, AdminProductState state) {
    if (excel.importing) return;
    final message = state.errorMessage ?? state.notice;
    if (message == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: state.errorMessage != null
            ? AppColor.errorColor
            : null,
      ),
    );
    if (state.errorMessage != null) {
      cubit.clearError();
    } else {
      cubit.clearNotice();
    }
  }
}
