import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_stock_movements_cubit.dart';
import 'package:admin_app/features/inventory/presentation/manager/admin_stock_movements_state.dart';
import 'package:admin_app/features/inventory/presentation/widgets/inventory_movement_dialog.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movement_details_dialog.dart';
import 'package:admin_app/features/inventory/presentation/widgets/stock_movements_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canAdjust = false,
  });

  static const String routeName = '/stock-movements';

  final AdminSearchController searchController;
  final AdminStockMovementsCubit? cubit;

  /// Records movements against the stock of the branches in scope.
  final bool canAdjust;

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  late final AdminStockMovementsCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminStockMovementsCubit();
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

  Future<void> _openMovement() async {
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
      searchMaterials: _cubit.searchMaterials,
      onRecord: _cubit.recordMovement,
    );
    if (saved != true || !mounted) return;
    _showMessage(S.movementRecorded);
  }

  Future<void> _openDetails(AdminStockMovement movement) {
    return showStockMovementDetailsDialog(context: context, movement: movement);
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
    return BlocProvider<AdminStockMovementsCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminStockMovementsCubit, AdminStockMovementsState>(
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
          return StockMovementsPageBody(
            movements: state.movements,
            total: state.total,
            page: state.page,
            pages: state.pages,
            pageSize: state.pageSize,
            search: state.search,
            type: state.type,
            period: state.period,
            branchId: state.branchId,
            filters: state.filters,
            metrics: state.metrics,
            isRefreshingRows: state.isRefreshingRows,
            canAdjust: widget.canAdjust,
            onSearchChanged: _onDirectorySearch,
            onTypeChanged: _cubit.setType,
            onPeriodChanged: _cubit.setPeriod,
            onBranchChanged: _cubit.setBranch,
            onClearFilters: _clearFilters,
            onPageChanged: _cubit.setPage,
            onOpen: _openDetails,
            onRecordMovement: _openMovement,
            onRefresh: _cubit.refresh,
            errorMessage: state.isFailure ? state.errorMessage : null,
          );
        },
      ),
    );
  }
}
