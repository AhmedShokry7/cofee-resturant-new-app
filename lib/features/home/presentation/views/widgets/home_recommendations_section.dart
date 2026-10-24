import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
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

  List<ProductModel> _recommend(
    List<ProductModel> pool,
    WeatherModel? weather,
    Set<String> favoriteIds,
  ) {
    final wanted = weather == null
        ? const <String>{}
        : weather.isHot
        ? _hotDayCategories
        : _coldDayCategories;
    final ranked = pool.indexed.toList()
      ..sort((a, b) {
        int score(ProductModel product) =>
            (favoriteIds.contains(product.id) ? 2 : 0) +
            (weather != null && wanted.contains(product.categorySlug) ? 1 : 0);
        final byScore = score(b.$2).compareTo(score(a.$2));
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return ranked
        .take(_maxRecommendations)
        .map((entry) => entry.$2)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, weatherState) {
        final pool = context.select(
          (HomeCubit c) => c.state.recommendationPool,
        );
        final favoriteIds = context.select((FavoritesCubit c) => c.state.ids);

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
          products: _recommend(pool, weather, favoriteIds),
          showViewMore: true,
        );
      },
    );
  }
}
