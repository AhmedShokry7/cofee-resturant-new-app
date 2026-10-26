import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_state.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_data_dialog.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_image_dialog.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_page_actions.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_page_body.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_records.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class BundlePage extends StatefulWidget {
  const BundlePage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/bundles';

  final AdminSearchController searchController;
  final AdminBundleCubit? cubit;

  @override
  State<BundlePage> createState() => _BundlePageState();
}

class _BundlePageState extends State<BundlePage> {
  late final AdminBundleCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminBundleCubit();
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
    return BlocProvider<AdminBundleCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminBundleCubit, AdminBundleState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasBundles) {
            return const AdminLoadingView();
          }
          if (state.status == AdminBundleStatus.failure && !state.hasBundles) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return BundlePageBody(
            bundles: state.bundles,
            search: _searchQuery,
            selectedIds: state.selectedIds,
            isDeletingSelected: state.isDeletingSelected,
            onSelect: (bundle) => _cubit.toggleSelection(bundle.id),
            onSelectAll: () => _cubit.selectMany(
              filterBundles(state.bundles, _searchQuery).map((b) => b.id),
            ),
            onClearSelection: _cubit.clearSelection,
            onDeleteSelected: () =>
                confirmDeleteSelectedBundles(context, _cubit),
            onAdd: () => showBundleCreateDialog(
              context: context,
              cubit: _cubit,
              products: state.products,
            ),
            onEdit: (bundle) => showBundleEditDialog(
              context: context,
              cubit: _cubit,
              bundle: bundle,
              products: state.products,
            ),
            onDelete: (bundle) => confirmDeleteBundle(context, _cubit, bundle),
            onToggleActive: (bundle) =>
                toggleBundleActive(context, _cubit, bundle),
            onChangeImage: (bundle) => showBundleImageDialog(
              context: context,
              cubit: _cubit,
              bundle: bundle,
            ),
          );
        },
      ),
    );
  }
}
