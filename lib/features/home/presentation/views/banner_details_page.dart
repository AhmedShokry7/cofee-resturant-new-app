import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
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
import 'package:new_coffee/core/theme/tokens.dart';

class BannerDetailsPage extends StatelessWidget {
  const BannerDetailsPage({super.key, required this.banner});

  static const routeName = "bannerDetailsRoute";

  final BannerModel banner;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BannerDetailsCubit(
        repository: context.read<CatalogRepository>(),
        banner: banner,
        branchId: context.read<HomeCubit>().branchId,
      ),
      child: const _BannerDetailsView(),
    );
  }
}

class _BannerDetailsView extends StatelessWidget {
  const _BannerDetailsView();

  /// The web address a banner may open, or null when it must open nothing.
  ///
  /// [Uri.parse] throws on a malformed value and the dashboard's url field is
  /// not validated on the way in, so one bad row would crash the page on a tap.
  /// Only a real http(s) address reaches the browser: a banner is not a way to
  /// make the customer's phone open something else.
  Uri? _webAddress(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
  }

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
        final uri = _webAddress(banner.targetUrl);
        if (uri == null) return;
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {
          // Nothing on screen depends on the browser having opened.
        }
      case BannerTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BannerDetailsCubit>().state;
    final banner = state.banner;
    return Scaffold(
      appBar: AppBar(title: Text(banner.title)),
      body: ListView(
        children: [
          SizedBox(
            height: AppDimensions.bannerHeroHeight,
            child: BannerImage(banner: banner, borderRadius: AppRadius.none),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A banner row is only required to carry its picture and its
                // target, so every line here can be empty. An empty Text is a
                // gap and an empty CustomBtn is a button with no label that
                // does nothing when pressed; neither is shown for what it is.
                if (banner.subtitle.isNotEmpty) ...[
                  Text(
                    banner.subtitle,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AppSpacing.sm),
                ],
                if (banner.title.isNotEmpty) ...[
                  Text(banner.title, style: AppFonts.semiBold24(context)),
                  SizedBox(height: AppSpacing.sm),
                ],
                if (banner.description.isNotEmpty) ...[
                  Text(
                    banner.description,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],
                if (banner.ctaLabel.isNotEmpty) ...[
                  CustomBtn(
                    text: banner.ctaLabel,
                    onPressed: () => _onCta(context, banner),
                  ),
                  SizedBox(height: AppSpacing.xl),
                ],
                HomeProductsCarousel(
                  title: S.youMayLike,
                  products: state.related,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
