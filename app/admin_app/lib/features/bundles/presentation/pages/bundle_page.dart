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

/// الباقات يقرؤها كل موظف، أما كتابتها فتطلب `catalog.product.write` (020)،
/// فالصفحة تُفتح للجميع وأدوات الكتابة تُحجب عمن ترفض قاعدته كتابته.
class BundlePage extends StatefulWidget {
  const BundlePage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManage = false,
  });

  static const String routeName = '/bundles';

  final AdminSearchController searchController;
  final AdminBundleCubit? cubit;
  final bool canManage;

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
            selectedIds: widget.canManage ? state.selectedIds : const {},
            isDeletingSelected: state.isDeletingSelected,
            onSelect: widget.canManage
                ? (bundle) => _cubit.toggleSelection(bundle.id)
                : null,
            onSelectAll: widget.canManage
                ? () => _cubit.selectMany(
                    filterBundles(state.bundles, _searchQuery).map((b) => b.id),
                  )
                : null,
            onClearSelection: widget.canManage ? _cubit.clearSelection : null,
            onDeleteSelected: widget.canManage
                ? () => confirmDeleteSelectedBundles(context, _cubit)
                : null,
            onAdd: widget.canManage
                ? () => showBundleCreateDialog(
                    context: context,
                    cubit: _cubit,
                    products: state.products,
                  )
                : null,
            onEdit: widget.canManage
                ? (bundle) => showBundleEditDialog(
                    context: context,
                    cubit: _cubit,
                    bundle: bundle,
                    products: state.products,
                  )
                : null,
            onDelete: widget.canManage
                ? (bundle) => confirmDeleteBundle(context, _cubit, bundle)
                : null,
            onToggleActive: widget.canManage
                ? (bundle) => toggleBundleActive(context, _cubit, bundle)
                : null,
            onChangeImage: widget.canManage
                ? (bundle) => showBundleImageDialog(
                    context: context,
                    cubit: _cubit,
                    bundle: bundle,
                  )
                : null,
          );
        },
      ),
    );
  }
}
