import 'package:material_ui/material_ui.dart';

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
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.resetKey,
  });

  final List<ProductModel> products;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int pageSize;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final String? resetKey;

  @override
  State<ProductsGridView> createState() => _ProductsGridViewState();
}

class _ProductsGridViewState extends State<ProductsGridView> {
  late int _shown;
  late final ScrollController _controller;
  bool _requestedMore = false;

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
    if (oldWidget.resetKey != widget.resetKey ||
        !_isAppendOnly(oldWidget.products, widget.products)) {
      _shown = widget.pageSize;
      _requestedMore = false;
      if (_controller.hasClients) _controller.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
    } else if (widget.products.length > oldWidget.products.length) {
      _shown += widget.products.length - oldWidget.products.length;
      _requestedMore = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasViewportDimension ||
        !position.hasContentDimensions ||
        position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels <
        position.maxScrollExtent - AppDimensions.gridLoadMoreAhead) {
      return;
    }
    if (_hasMore) {
      setState(() {
        _shown = (_shown + widget.pageSize).clamp(0, _total);
      });
    } else {
      _requestServerPage();
    }
  }

  void _loadMoreIfContentTooShort() {
    if (!_controller.hasClients || (!_hasMore && !widget.hasMore)) return;
    final position = _controller.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
      return;
    }
    if (position.maxScrollExtent <= 0 && _hasMore) {
      setState(() {
        _shown = (_shown + widget.pageSize).clamp(0, _total);
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreIfContentTooShort(),
      );
    } else if (position.maxScrollExtent <= 0) {
      _requestServerPage();
    }
  }

  void _requestServerPage() {
    if (!widget.hasMore ||
        widget.isLoadingMore ||
        _requestedMore ||
        widget.onLoadMore == null) {
      return;
    }
    _requestedMore = true;
    widget.onLoadMore!.call();
  }

  bool _isAppendOnly(List<ProductModel> a, List<ProductModel> b) {
    if (b.length < a.length) return false;
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
        if (_hasMore || widget.hasMore || widget.isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.none,
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
