import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/popular_card.dart';

class ProductsGridView extends StatefulWidget {
  const ProductsGridView({
    super.key,
    required this.products,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.pageSize = 6,
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

  @override
  void initState() {
    super.initState();
    _shown = widget.pageSize;
  }

  @override
  void didUpdateWidget(covariant ProductsGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameProducts(oldWidget.products, widget.products)) {
      _shown = widget.pageSize;
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
    final total = widget.products.length;
    final shown = _shown < total ? _shown : total;
    final hasMore = shown < total;

    return CustomScrollView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      slivers: [
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.all(SpacingTokens.lg.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: SpacingTokens.md.w,
              mainAxisSpacing: SpacingTokens.md.h,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => PopularCard(product: widget.products[index]),
              childCount: shown,
            ),
          ),
        ),
        if (hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.lg.w,
                0,
                SpacingTokens.lg.w,
                SpacingTokens.lg.h,
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _shown += widget.pageSize),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: SpacingTokens.lg.w,
                      vertical: SpacingTokens.sm.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.primaryColor),
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Text(
                      "View more",
                      style: AppFonts.medium14(
                        context,
                      ).copyWith(color: AppColor.primaryColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
