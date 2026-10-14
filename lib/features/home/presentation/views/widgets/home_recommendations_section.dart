import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/data/recommendations.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

class HomeRecommendationsSection extends StatelessWidget {
  const HomeRecommendationsSection({super.key});

  static const Set<String> _hotDayCategories = {
    "Cold Coffee",
    "Soft Drinks",
    "Milkshakes",
  };
  static const Set<String> _coldDayCategories = {"Hot Coffee", "Tea"};

  List<ProductModel> _byWeather(WeatherModel weather) {
    final categories = weather.isHot ? _hotDayCategories : _coldDayCategories;
    return getMenuList()
        .where((product) => categories.contains(product.category))
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, state) {
        if (state is WeatherLoaded) {
          final weather = state.weather;
          return HomeProductsCarousel(
            title: "Recommendations",
            subtitle: weather.isHot
                ? "Cool picks for a warm day"
                : "Warm picks for a chilly day",
            products: _byWeather(weather),
          );
        }
        return HomeProductsCarousel(
          title: "Recommendations",
          products: getRecommendedProducts(),
        );
      },
    );
  }
}
