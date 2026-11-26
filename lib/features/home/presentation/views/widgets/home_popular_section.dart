import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';

/// "Popular" now means featured, not "the whole menu in array order".
///
/// Before this it passed getMenuList() straight through, so every product was
/// shown as popular because nothing ranked them.
class HomePopularSection extends StatelessWidget {
  const HomePopularSection({
    super.key,
    this.title,
    this.maxItems = 10,
    this.showPrice = true,
    this.showViewMore = true,
    this.titleStyle,
  });

  final String? title;
  final int maxItems;
  final bool showPrice;
  final bool showViewMore;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final products = context.watch<HomeCubit>().state.popular;
    if (products.isEmpty) {
      // Ranked sections are legitimately empty until there are sales; hide the
      // header rather than showing an empty carousel.
      return const SizedBox.shrink();
    }
    return HomeProductsCarousel(
      title: title?.trim().isNotEmpty == true ? title!.trim() : S.popular,
      products: products,
      maxItems: maxItems,
      showPrice: showPrice,
      showViewMore: showViewMore,
      titleStyle: titleStyle,
    );
  }
}
