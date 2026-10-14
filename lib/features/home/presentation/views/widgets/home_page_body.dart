import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_single_banner_section.dart';

class HomePageBody extends StatelessWidget {
  const HomePageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
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
