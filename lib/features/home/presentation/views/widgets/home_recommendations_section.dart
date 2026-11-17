import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

class HomeRecommendationsSection extends StatelessWidget {
  const HomeRecommendationsSection({
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
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, weatherState) {
        final home = context.watch<HomeCubit>().state;
        final favoriteIds = context.select((FavoritesCubit c) => c.state.ids);

        // Only offer the seasonal subtitle once the pool has actually loaded,
        // otherwise the heading promises picks that are not there yet.
        final weather = weatherState is WeatherLoaded
            ? weatherState.weather
            : null;
        final hasWeather =
            weather != null && home.recommendationPool.isNotEmpty;

        return HomeProductsCarousel(
          title: title?.trim().isNotEmpty == true
              ? title!.trim()
              : S.recommendations,
          subtitle: !hasWeather
              ? null
              : weather.isHot
              ? S.hotDayPicks
              : S.coldDayPicks,
          products: home.recommendations(
            weather: weather,
            favoriteIds: favoriteIds,
          ),
          maxItems: maxItems,
          showPrice: showPrice,
          showViewMore: showViewMore,
          titleStyle: titleStyle,
        );
      },
    );
  }
}
