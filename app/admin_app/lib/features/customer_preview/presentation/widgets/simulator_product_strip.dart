import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_product_card.dart';

/// شريط منتجات أفقي، كما يقيس تطبيق العميل شريطه: الارتفاع من عرض البطاقة
/// ونسبتها، فلا تُقص بطاقة ولا يبقى فراغ تحتها.
///
/// بلا حشو جانبي: المقطع الذي يغلّفه يعطيه حافّته، كما يفعل `HomeSection` عند
/// العميل. الحشو هنا كان يضيف ستة عشر على ستة عشر.
class SimulatorProductStrip extends StatelessWidget {
  const SimulatorProductStrip({
    super.key,
    required this.products,
    required this.language,
    this.showPrice = true,
  });

  final List<PreviewProduct> products;
  final AppLanguage language;

  /// سعر على البطاقة أو بلاه، وبقية البطاقة كما عند الزبون.
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.simulatorProductStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => SizedBox(
          width: AppDimensions.simulatorProductCardWidth,
          child: SimulatorProductCard(
            product: products[index],
            language: language,
            showPrice: showPrice,
          ),
        ),
      ),
    );
  }
}
