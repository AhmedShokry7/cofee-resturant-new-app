import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class BannerDetailsPage extends StatelessWidget {
  const BannerDetailsPage({super.key, required this.banner});

  static const routeName = "bannerDetailsRoute";

  final BannerModel banner;

  @override
  Widget build(BuildContext context) {
final related = context
        .select((HomeCubit c) => c.state.productsForBanner(banner));
    return Scaffold(
      appBar: AppBar(title: Text(banner.title)),
      body: ListView(
        children: [
          SizedBox(
            height: 220.h,
            child: BannerImage(banner: banner, borderRadius: 0),
          ),
          Padding(
            padding: EdgeInsets.all(SpacingTokens.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.subtitle,
                  style: AppFonts.regular14(
                    context,
                  ).copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: SpacingTokens.sm.h),
                Text(banner.title, style: AppFonts.semiBold24(context)),
                SizedBox(height: SpacingTokens.sm.h),
                Text(
                  banner.description,
                  style: AppFonts.regular14(
                    context,
                  ).copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: SpacingTokens.lg.h),
                CustomBtn(
                  text: banner.ctaLabel,
                  onPressed: () {
                    context.read<SearchCubit>().search(banner.targetCategory);
                    Navigator.of(context).pushNamed(SearchPage.routeName);
                  },
                ),
                SizedBox(height: SpacingTokens.xl.h),
                HomeProductsCarousel(
                  title: "You may like",
                  products: related,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

