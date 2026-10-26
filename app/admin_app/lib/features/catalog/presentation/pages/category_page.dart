import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/catalog/presentation/manager/admin_category_cubit.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_excel_controller.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_state.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// The categories of the catalogue, with their Excel import and export.
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/categories';

  final AdminSearchController searchController;
  final AdminCategoryCubit? cubit;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late final AdminCategoryCubit _cubit;
  late final bool _ownsCubit;
  late final CategoryExcelController _excel;
  String _searchQuery = '';
  double? _importProgress;
  double? _exportProgress;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminCategoryCubit();
    if (_ownsCubit) _cubit.load();
    _excel = CategoryExcelController(cubit: _cubit, onProgress: _onProgress);
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

  void _onProgress(double? value) {
    if (!mounted) return;
    setState(() {
      _importProgress = _excel.importing ? value : null;
      _exportProgress = _excel.exporting ? value : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCategoryCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminCategoryCubit, AdminCategoryState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasCategories) {
            return const AdminLoadingView();
          }
          if (state.status == AdminCategoryStatus.failure &&
              !state.hasCategories) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return CategoryPageBody(
            cubit: _cubit,
            excel: _excel,
            categories: state.categories,
            search: _searchQuery,
            importProgress: _importProgress,
            exportProgress: _exportProgress,
            selectedIds: state.selectedIds,
            isDeletingSelected: state.isDeletingSelected,
          );
        },
      ),
    );
  }
}
