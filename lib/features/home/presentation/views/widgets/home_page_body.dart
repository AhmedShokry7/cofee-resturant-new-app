import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_loading_view.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_single_banner_section.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class HomePageBody extends StatelessWidget {
  const HomePageBody({super.key});

  /// Pull-to-refresh reloads the catalogue snapshot and the weather rule
  /// behind the recommendations in one gesture, like other food apps.
  Future<void> _refresh(BuildContext context) => Future.wait([
    context.read<HomeCubit>().load(),
    context.read<WeatherCubit>().load(),
  ]);

  static bool _isEmpty(HomeState state) =>
      state.banners.isEmpty &&
      state.bundles.isEmpty &&
      state.categories.isEmpty &&
      state.popular.isEmpty &&
      state.recommendationPool.isEmpty;

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
          if (!state.isLoading && state.error != null && _isEmpty(state)) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(SpacingTokens.lg.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: S.homeLoadError,
                      subtitle: state.error!,
                    ),
                    SizedBox(height: SpacingTokens.md.h),
                    CustomBtn(
                      text: S.retry,
                      onPressed: () => context.read<HomeCubit>().load(),
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
              padding: EdgeInsets.only(
                top: SpacingTokens.md.h,
                bottom: SpacingTokens.lg.h,
              ),
              children: [
                const _HomeSection(child: HomeHeader()),
                SizedBox(height: SpacingTokens.lg.h),
                const _HomeSection(child: HomeSearchBar()),
                SizedBox(height: SpacingTokens.lg.h),
                const HomeBannerSection(),
                SizedBox(height: SpacingTokens.lg.h),
                const _HomeSection(child: HomeCategoriesSection()),
                SizedBox(height: SpacingTokens.lg.h),
                const _HomeSection(child: HomePopularSection()),
                SizedBox(height: SpacingTokens.lg.h),
                const _HomeSection(child: HomeSingleBannerSection()),
                SizedBox(height: SpacingTokens.xl.h),
                const _HomeSection(child: HomeRecommendationsSection()),
                SizedBox(height: SpacingTokens.lg.h),
                const _HomeSection(child: HomeBundlesSection()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SpacingTokens.lg.w),
      child: child,
    );
  }
}
