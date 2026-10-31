import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_excel_controller.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_view.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';

/// The products of the catalogue, with their images and their Excel jobs.
///
/// The page owns the page level state only: the cubit of the catalogue, the
/// Excel jobs and the search query of the shell.
///
/// [canManage] و[canManageCategories] صلاحيتان منفصلتان تسألهما القاعدة في كل
/// كتابة (`catalog.product.write` في 117 و184، و`catalog.category.write` في
/// 117)، فالصفحة تُعرض للجميع أما أدوات الكتابة فلمن يُقبل فعله.
class ProductPage extends StatefulWidget {
  const ProductPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManage = false,
    this.canManageCategories = false,
  });

  static const String routeName = '/products';

  final AdminSearchController searchController;
  final AdminProductCubit? cubit;
  final bool canManage;
  final bool canManageCategories;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final AdminProductCubit _cubit;
  late final bool _ownsCubit;
  late final ProductExcelController _excel;
  Timer? _searchDebounce;
  double? _importProgress;
  double? _exportProgress;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminProductCubit();
    if (_ownsCubit) _cubit.load();
    _excel = ProductExcelController(cubit: _cubit, onProgress: _onProgress);
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _cubit.search(query);
    });
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
    return ProductPageView(
      cubit: _cubit,
      excel: _excel,
      canManage: widget.canManage,
      canManageCategories: widget.canManageCategories,
      importProgress: _importProgress,
      exportProgress: _exportProgress,
    );
  }
}
