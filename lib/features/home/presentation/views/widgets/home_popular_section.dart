import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';

/// "Popular" now means featured, not "the whole menu in array order".
///
/// Before this it passed getMenuList() straight through, so every product was
/// shown as popular because nothing ranked them.
class HomePopularSection extends StatelessWidget {
  const HomePopularSection({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<HomeCubit>().state.popular;
    if (products.isEmpty) {
      // Ranked sections are legitimately empty until there are sales; hide the
      // header rather than showing an empty carousel.
      return const SizedBox.shrink();
    }
    return HomeProductsCarousel(
      title: "Popular",
      products: products,
      showViewMore: true,
    );
  }
}
