import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/banner_opener.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// A single promo banner below the carousel.
///
/// This reads only banners assigned to the in-page placement. Its order and
/// membership are independent of the top carousel.
class HomeSingleBannerSection extends StatelessWidget {
  const HomeSingleBannerSection({
    super.key,
    this.bannerIndex = 0,
    this.height,
    this.radius = AppRadius.r8,
  });

  /// فهرس البانر في قائمة البانرات المنشورة، ١ = الثاني كما كان.
  final int bannerIndex;
  final double? height;

  /// تقويس زوايا البانر الترويجي. الغائب r8 كما كان.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final banner =
        context.watch<HomeCubit>().state.promoBannerAt(bannerIndex);
    if (banner == null) return const SizedBox.shrink();
    return SizedBox(
      height: height ?? AppDimensions.homeBannerHeight,
      child: Semantics(
        link: true,
        label: banner.title,
        child: Material(
          color: AppColor.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            // The same rule as the carousel above it: the banner's own target,
            // and the banner page only when there is nothing to open.
            onTap: () => openBanner(
              context,
              banner,
              fallback: () => Navigator.of(context)
                  .pushNamed(BannerDetailsPage.routeName, arguments: banner),
            ),
            borderRadius: BorderRadius.circular(radius),
            child: BannerImage(banner: banner),
          ),
        ),
      ),
    );
  }
}
