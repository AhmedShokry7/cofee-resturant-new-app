import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_card.dart';

/// شبكة منتجات العميل بنفس ما يفعله تطبيقه: عشر بطاقات تُعرض أولًا، والباقي
/// ينزل أثناء النزول، والحلّاق يظهر أمام آخر سطر.
///
/// عمودها يتكاثر عند سقف عرض البطاقة نفسه الذي وضعه العميل — هاتف باثنين،
/// لوح بثلاثة — فالصورة لا تتجاوز 240 ولا تُقصّ.
///
/// المحاكي لا يستدعي صفحة من القاعدة: الصفوف كلها وصلت في قراءة واحدة، وهذا
/// يعيد توزيعها كما يوزعها العميل على شاشته، لا يخفي بيانات عن الموظف.
class SimulatorProductGrid extends StatefulWidget {
  const SimulatorProductGrid({
    super.key,
    required this.products,
    required this.language,
    this.showPrice = true,
  });

  final List<PreviewProduct> products;
  final AppLanguage language;

  /// إظهار السعر قرار المحرّر على المقطع، والرسم نفسه بطاقة الزبون.
  final bool showPrice;

  /// `ProductsGridView.pageSize` عند العميل.
  static const int pageSize = 10;

  /// delegate الشبكة نفسها، لمن يرسم الصفوف داخل تمرير صفحة لا داخل تمريرها
  /// الخاص: عمودان على الهاتف وثلاثة على اللوح، بنفس سقف البطاقة نفسه.
  static const SliverGridDelegate gridDelegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: AppDimensions.simulatorProductCardMaxWidth,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: AppDimensions.simulatorProductCardAspect,
      );

  /// حشو الشبكة من المقطع نفسه كما عند العميل: اثنا عشر على الجوانب، وستة عشر
  /// تحت آخر سطر.
  static const EdgeInsets gridPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.lg,
  );

  @override
  State<SimulatorProductGrid> createState() => _SimulatorProductGridState();
}

class _SimulatorProductGridState extends State<SimulatorProductGrid> {
  late int _shown = widget.products.length.clamp(
    0,
    SimulatorProductGrid.pageSize,
  );
  final ScrollController _controller = ScrollController();

  bool get _hasMore => _shown < widget.products.length;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillIfShort());
  }

  @override
  void didUpdateWidget(covariant SimulatorProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameProducts(oldWidget.products, widget.products)) return;
    _shown = widget.products.length.clamp(0, SimulatorProductGrid.pageSize);
    if (_controller.hasClients) _controller.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillIfShort());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || !_hasMore) return;
    final position = _controller.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      return;
    }
    if (position.pixels >=
        position.maxScrollExtent - AppDimensions.simulatorGridLoadMoreAhead) {
      setState(() {
        _shown = (_shown + SimulatorProductGrid.pageSize).clamp(
          0,
          widget.products.length,
        );
      });
    }
  }

  /// المحتوى أقصر من الشاشة فلا نزول يُطلق البقية: يزيدها حتى تُملأ.
  void _fillIfShort() {
    if (!_controller.hasClients || !_hasMore) return;
    final position = _controller.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillIfShort());
      return;
    }
    if (position.maxScrollExtent > 0) return;
    setState(() {
      _shown = (_shown + SimulatorProductGrid.pageSize).clamp(
        0,
        widget.products.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillIfShort());
  }

  bool _sameProducts(List<PreviewProduct> a, List<PreviewProduct> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown.clamp(0, widget.products.length);
    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverPadding(
          padding: SimulatorProductGrid.gridPadding,
          sliver: SliverGrid(
            gridDelegate: SimulatorProductGrid.gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) => SimulatorProductCard(
                product: widget.products[index],
                language: widget.language,
                showPrice: widget.showPrice,
              ),
              childCount: shown,
            ),
          ),
        ),
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
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
