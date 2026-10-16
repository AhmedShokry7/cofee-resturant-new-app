import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class BannerDetailsPage extends StatelessWidget {
  const BannerDetailsPage({super.key, required this.banner});

  static const routeName = "bannerDetailsRoute";

  final BannerModel banner;

  Future<void> _onCta(BuildContext context) async {
    switch (banner.targetType) {
      case 'category':
        if (banner.targetId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CategoriesPage(initialCategoryId: banner.targetId),
            ),
          );
        }
        return;
      case 'product':
        final product = banner.targetProduct;
        if (product != null) {
          Navigator.of(context)
              .pushNamed(ProductDetailsPage.routeName, arguments: product);
        }
        return;
      case 'bundle':
        final bundle = banner.targetBundle;
        if (bundle != null) {
          Navigator.of(context)
              .pushNamed(BundleDetailsPage.routeName, arguments: bundle);
        }
        return;
      case 'url':
        final url = banner.targetUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        return;
      case 'none':
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final related = context.select(
      (HomeCubit c) => c.state.productsForBanner(banner),
    );
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
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: SpacingTokens.sm.h),
                Text(banner.title, style: AppFonts.semiBold24(context)),
                SizedBox(height: SpacingTokens.sm.h),
                Text(
                  banner.description,
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: SpacingTokens.lg.h),
                CustomBtn(
                  text: banner.ctaLabel,
                  onPressed: () => _onCta(context),
                ),
                SizedBox(height: SpacingTokens.xl.h),
                HomeProductsCarousel(title: S.youMayLike, products: related),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
