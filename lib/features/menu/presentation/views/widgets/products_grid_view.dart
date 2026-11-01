import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProductsGridView extends StatefulWidget {
  const ProductsGridView({
    super.key,
    required this.products,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.pageSize = 10,
  });

  final List<ProductModel> products;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int pageSize;

  @override
  State<ProductsGridView> createState() => _ProductsGridViewState();
}

class _ProductsGridViewState extends State<ProductsGridView> {
  late int _shown;
  late final ScrollController _controller;

  int get _total => widget.products.length;
  bool get _hasMore => _shown < _total;

  @override
  void initState() {
    super.initState();
    _shown = widget.pageSize;
    _controller = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadMoreIfContentTooShort(),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductsGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameProducts(oldWidget.products, widget.products)) {
      _shown = widget.pageSize;
      if (_controller.hasClients) _controller.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
    }
  }

  void _onScroll() {
    if (!_controller.hasClients || !_hasMore) return;
    final position = _controller.position;
    if (!position.hasViewportDimension ||
        !position.hasContentDimensions ||
        position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels >=
        position.maxScrollExtent - AppDimensions.gridLoadMoreAhead) {
      setState(() {
        _shown = (_shown + widget.pageSize).clamp(0, _total);
      });
    }
  }

  void _loadMoreIfContentTooShort() {
    if (!_controller.hasClients || !_hasMore) return;
    final position = _controller.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
      return;
    }
    if (position.maxScrollExtent <= 0) {
      setState(() {
        _shown = (_shown + widget.pageSize).clamp(0, _total);
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
    }
  }

  bool _sameProducts(List<ProductModel> a, List<ProductModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown.clamp(0, _total);

    return CustomScrollView(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      slivers: [
        SliverPadding(
          padding:
              widget.padding ??
              EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
          sliver: SliverGrid(
            // The row counts its own cards: a phone keeps two, a tablet gains
            // a third, and a card stops widening at the product card ceiling.
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: AppBreakpoints.productCardMaxWidth,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: ProductCard.cardAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(product: widget.products[index]),
              childCount: shown,
            ),
          ),
        ),
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Center(
                child: SizedBox(
                  height: AppSpacing.xl,
                  width: AppSpacing.xl,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.spinnerStroke,
                    color: AppColor.primaryColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
