import 'package:flutter/material.dart';

import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';

class HomePopularSection extends StatelessWidget {
  const HomePopularSection({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeProductsCarousel(title: "Popular", products: getMenuList());
  }
}
