import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/data/repositories/admin_inventory_repository.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_inventory_cubit.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_inventory_state.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_format.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_material_dialog.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_movement_dialog.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canAdjust = false,
    this.canEdit = false,
  });

  static const String routeName = '/inventory';

  final AdminSearchController searchController;
  final AdminInventoryCubit? cubit;

  /// Records movements against the stock of the branches in scope.
  final bool canAdjust;

  /// Creates, edits and deletes the material master.
  final bool canEdit;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final AdminInventoryCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminInventoryCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) => _cubit.updateSearch(query);

  void _onDirectorySearch(String value) {
    _cubit.updateSearch(value);
    widget.searchController.update(value);
  }

  void _clearFilters() {
    _cubit.clearFilters();
    widget.searchController.clear();
  }

  Future<void> _openMaterial([AdminInventoryItem? item]) async {
    if (!widget.canEdit) return;
    final saved = item == null
        ? await showInventoryMaterialCreateDialog(
            context: context,
            cubit: _cubit,
          )
        : await showInventoryMaterialEditDialog(
            context: context,
            cubit: _cubit,
            item: item,
          );
    if (saved != true || !mounted) return;
    _showMessage(item == null ? S.materialCreated : S.materialUpdated);
  }

  Future<void> _openMovement([AdminInventoryItem? item]) async {
    if (!widget.canAdjust) return;
    final filters = _cubit.state.filters;
    if (!filters.hasBranches) {
      _showMessage(S.movementNoBranches, error: true);
      return;
    }
    final saved = await showInventoryMovementDialog(
      context: context,
      filters: filters,
      branchId: _cubit.state.branchId,
      initialItem: item,
      searchMaterials: _cubit.searchMaterials,
      onRecord: _cubit.recordMovement,
    );
    if (saved != true || !mounted) return;
    _showMessage(S.movementRecorded);
  }

  Future<void> _delete(AdminInventoryItem item) async {
    if (!widget.canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          S.materialDeleteTitle,
          style: const TextStyle(
            fontSize: AppFontSizes.size15,
            fontWeight: AppFontWeights.bold,
          ),
        ),
        content: Text(
          S.materialDeleteMessage(inventoryMaterialName(item)),
          style: const TextStyle(
            fontSize: AppFontSizes.size11_5,
            height: AppTextHeights.line1_6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.errorColor,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Text(
              S.delete,
              style: const TextStyle(
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final outcome = await _cubit.deleteMaterial(item.id);
    if (!mounted) return;
    if (outcome == InventoryMutationOutcome.success) {
      _showMessage(S.materialDeleted);
    } else {
      _showMessage(materialMutationErrorMessage(outcome), error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminInventoryCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminInventoryCubit, AdminInventoryState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return InventoryPageBody(
            items: state.items,
            total: state.total,
            page: state.page,
            pages: state.pages,
            pageSize: state.pageSize,
            search: state.search,
            category: state.category,
            statusFilter: state.statusFilter,
            branchId: state.branchId,
            filters: state.filters,
            metrics: state.metrics,
            isRefreshingRows: state.isRefreshingRows,
            canAdjust: widget.canAdjust,
            canEdit: widget.canEdit,
            onAdd: _openMaterial,
            onEdit: _openMaterial,
            onMovement: _openMovement,
            onRecordMovement: _openMovement,
            onDelete: _delete,
            onSearchChanged: _onDirectorySearch,
            onCategoryChanged: _cubit.setCategory,
            onStatusChanged: _cubit.setStatusFilter,
            onBranchChanged: _cubit.setBranch,
            onClearFilters: _clearFilters,
            onPageChanged: _cubit.setPage,
            onRefresh: _cubit.refresh,
            errorMessage: state.isFailure ? state.errorMessage : null,
          );
        },
      ),
    );
  }
}
