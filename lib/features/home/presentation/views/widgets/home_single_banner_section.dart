import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// A single promo banner below the carousel.
///
/// Before this it rendered getBannersList().first, so it re-displayed the
/// banner the carousel had already shown. It now uses the second banner, and
/// hides itself when there is no second one rather than crashing on .first.
class HomeSingleBannerSection extends StatelessWidget {
  const HomeSingleBannerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final banner = context.watch<HomeCubit>().state.promoBanner;
    if (banner == null) return const SizedBox.shrink();
    return SizedBox(
      height: AppDimensions.homeBannerHeight,
      child: Semantics(
        link: true,
        label: banner.title,
        child: Material(
          color: AppColor.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: InkWell(
            onTap: () =>
                Navigator.of(context)
                    .pushNamed(BannerDetailsPage.routeName, arguments: banner),
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: BannerImage(banner: banner),
          ),
        ),
      ),
    );
  }
}
