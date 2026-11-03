import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_link.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/home/presentation/views/see_all_products_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeProductsCarousel extends StatelessWidget {
  const HomeProductsCarousel({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
    this.maxItems = 10,
    this.showViewMore = false,
  });

  final String title;
  final String? subtitle;
  final List<ProductModel> products;

  /// How many cards the strip shows before the title's link takes over.
  ///
  /// One screen of cards: past that the row stops being something a thumb
  /// sweeps, and the full page exists for exactly that case.
  final int maxItems;
  final bool showViewMore;

  void _openAll(BuildContext context) {
    Navigator.of(context).pushNamed(
      SeeAllProductsPage.routeName,
      arguments: SeeAllProductsArgs(
        title: title,
        subtitle: subtitle,
        products: products,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = products.length > maxItems
        ? products.sublist(0, maxItems)
        : products;
    // An empty pool must hide the whole block: title plus a fixed-height
    // void reads as a broken section, not as "no results".
    if (displayed.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: title,
          trailing: showViewMore
              ? HomeSectionLink(
                  label: S.viewMore,
                  onTap: () => _openAll(context),
                )
              : null,
        ),
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.greyColor),
          ),
        ],
        SizedBox(height: AppSpacing.md),
        // The strip height is derived from the card width and aspect ratio
        // instead of a fixed value, so taller cards always fit exactly on
        // every screen size without clipping or dead space.
        SizedBox(height: AppSpacing.xs),

        SizedBox(
          height: ProductCard.stripWidth / ProductCard.cardAspectRatio,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayed.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) =>
                ProductCard(product: displayed[index]),
          ),
        ),
      ],
    );
  }
}
