import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_loading_view.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_single_banner_section.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomePageBody extends StatelessWidget {
  const HomePageBody({super.key});

  /// Pull-to-refresh reload the catalogue snapshot and the weather rule behind
  /// the recommendations in one gesture, like other food apps.
  ///
  /// It forces the read past the cache: a refresh gesture that answered from the
  /// cache it had just read would refresh nothing.
  Future<void> _refresh(BuildContext context) => Future.wait([
    context.read<HomeCubit>().load(forceRefresh: true),
    context.read<WeatherCubit>().load(),
  ]);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          // First load: every section is empty, so show skeletons that mirror
          // the real sections instead of a blank page with one spinner.
          if (state.isFirstLoad) {
            return RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: const HomeLoadingView(),
            );
          }
          // Total failure: nothing to show and no silent blank page. The
          // message names the degraded sections and offers a retry.
          if (!state.isLoading && state.error != null && state.hasNoContent) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      icon: AppIcons.offline,
                      title: S.homeLoadError,
                      subtitle: state.error!,
                    ),
                    SizedBox(height: AppSpacing.md),
                    CustomBtn(
                      text: S.retry,
                      onPressed: () =>
                          context.read<HomeCubit>().load(forceRefresh: true),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              // Pull-to-refresh must work even when the content is short.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: HomeSection.bodyPadding,
              children: [
                const HomeSection(child: HomeHeader()),
                SizedBox(height: AppSpacing.md),
                const HomeSection(child: HomeSearchBar()),
                SizedBox(height: AppSpacing.md),
                const HomeBannerSection(),
                const HomeSection(child: HomeCategoriesSection()),
                SizedBox(height: AppSpacing.md),
                const HomeSection(child: HomePopularSection()),
                SizedBox(height: AppSpacing.md),
                const HomeSection(child: HomeSingleBannerSection()),
                SizedBox(height: AppSpacing.md),
                const HomeSection(child: HomeRecommendationsSection()),
                SizedBox(height: AppSpacing.md),
                const HomeSection(child: HomeBundlesSection()),
              ],
            ),
          );
        },
      ),
    );
  }
}
