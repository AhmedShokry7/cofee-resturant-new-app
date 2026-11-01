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
import 'package:new_coffee/features/home/presentation/manager/banner_details/banner_details_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class BannerDetailsPage extends StatefulWidget {
  const BannerDetailsPage({super.key, required this.banner});

  static const routeName = "bannerDetailsRoute";

  final BannerModel banner;

  @override
  State<BannerDetailsPage> createState() => _BannerDetailsPageState();
}

class _BannerDetailsPageState extends State<BannerDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BannerDetailsCubit(
        repository: context.read<CatalogRepository>(),
        banner: widget.banner,
      ),
      child: const _BannerDetailsView(),
    );
  }
}

class _BannerDetailsView extends StatelessWidget {
  const _BannerDetailsView();

  Future<void> _onCta(BuildContext context, BannerModel banner) async {
    final nav = Navigator.of(context);
    switch (banner.target) {
      case BannerTarget.category:
        final id = banner.targetId;
        if (id != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => CategoriesPage(initialCategoryId: id),
            ),
          );
        }
      case BannerTarget.product:
        final product = banner.targetProduct;
        if (product != null) {
          nav.pushNamed(ProductDetailsPage.routeName, arguments: product);
        }
      case BannerTarget.bundle:
        final bundle = banner.targetBundle;
        if (bundle != null) {
          nav.pushNamed(BundleDetailsPage.routeName, arguments: bundle);
        }
      case BannerTarget.url:
        final url = banner.targetUrl;
        if (url == null || url.isEmpty) return;
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      case BannerTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = context.watch<BannerDetailsCubit>().state;
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
                  onPressed: () => _onCta(context, banner),
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
