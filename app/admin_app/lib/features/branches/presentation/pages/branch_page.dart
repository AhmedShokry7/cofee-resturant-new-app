import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_state.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_data_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_delivery_settings_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_image_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_product_pricing_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_page_actions.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class BranchPage extends StatefulWidget {
  const BranchPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManagePricing = false,
  });

  static const String routeName = '/branches';

  final AdminSearchController searchController;
  final AdminBranchCubit? cubit;
  final bool canManagePricing;

  @override
  State<BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<BranchPage> {
  late final AdminBranchCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminBranchCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminBranchCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminBranchCubit, AdminBranchState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasBranches) {
            return const AdminLoadingView();
          }
          if (state.status == AdminBranchStatus.failure && !state.hasBranches) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return BranchPageBody(
            branches: state.branches,
            search: _searchQuery,
            onAdd: () =>
                showBranchCreateDialog(context: context, cubit: _cubit),
            onEdit: (branch) => showBranchEditDialog(
              context: context,
              cubit: _cubit,
              branch: branch,
            ),
            onDelete: (branch) => confirmDeleteBranch(context, _cubit, branch),
            onToggleActive: (branch) =>
                toggleBranchActive(context, _cubit, branch),
            onChangeImage: (branch) => showBranchImageDialog(
              context: context,
              cubit: _cubit,
              branchId: branch.id,
              imageUrl: branch.imageUrl,
            ),
            onManageDelivery: (branch) => showBranchDeliverySettingsDialog(
              context: context,
              branch: branch,
              onEditBranch: () => showBranchEditDialog(
                context: context,
                cubit: _cubit,
                branch: branch,
              ),
            ),
            onManagePricing: widget.canManagePricing
                ? (branch) => showBranchProductPricingDialog(
                    context: context,
                    branch: branch,
                  )
                : null,
          );
        },
      ),
    );
  }
}
