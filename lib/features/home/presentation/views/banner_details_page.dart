import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/banner_details/banner_details_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/banner_opener.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
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

  /// The banner's picture is not repeated here.
  ///
  /// The customer pressed that picture to reach this page, so showing it again
  /// above its own text spends the room the products under the banner need. The
  /// picture stays where it is: the row on home.
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BannerDetailsCubit>().state;
    final banner = state.banner;
    return Scaffold(
      appBar: AppBar(title: Text(banner.title)),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
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
            // The button opens the same thing a tap on the banner picture does,
            // with no fallback: this page is what the banner shows when it has
            // nowhere to send the customer, and a button that reopened it would
            // stack a second copy on the one it sits on.
            CustomBtn(
              text: banner.ctaLabel,
              onPressed: () => openBanner(context, banner),
            ),
            SizedBox(height: AppSpacing.xl),
          ],
          HomeProductsCarousel(title: S.youMayLike, products: state.related),
        ],
      ),
    );
  }
}
