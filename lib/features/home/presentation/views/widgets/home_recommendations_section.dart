import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

class HomeRecommendationsSection extends StatelessWidget {
  const HomeRecommendationsSection({super.key});

  /// Category slugs that suit warm weather. Slugs, not display names: renaming
  /// a category must not silently break the rule, which is exactly what
  /// happened when this matched on English strings.
  static const Set<String> _hotDayCategories = {
    'cold-coffee',
    'soft-drinks',
    'milkshakes',
  };

  static const Set<String> _coldDayCategories = {'hot-coffee', 'tea'};

  static const int _maxRecommendations = 4;

  List<ProductModel> _byWeather(List<ProductModel> pool, WeatherModel weather) {
    final wanted = weather.isHot ? _hotDayCategories : _coldDayCategories;
    final matches = pool
        .where((p) => wanted.contains(p.categorySlug))
        .take(_maxRecommendations)
        .toList();
    if (matches.isNotEmpty) return matches;

    // The branch may stock none of the weather-matched categories. Showing the
    // pool in that case beats hiding the section.
    return pool.take(_maxRecommendations).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, weatherState) {
        final pool = context.select(
          (HomeCubit c) => c.state.recommendationPool,
        );

        // Only offer the seasonal subtitle once the pool has actually loaded,
        // otherwise the heading promises picks that are not there yet.
        final weather = weatherState is WeatherLoaded
            ? weatherState.weather
            : null;
        final hasWeather = weather != null && pool.isNotEmpty;

        return HomeProductsCarousel(
          title: S.recommendations,
          subtitle: !hasWeather
              ? null
              : weather.isHot
              ? S.hotDayPicks
              : S.coldDayPicks,
          products: hasWeather
              ? _byWeather(pool, weather)
              : pool.take(_maxRecommendations).toList(),
          showViewMore: true,
        );
      },
    );
  }
}
