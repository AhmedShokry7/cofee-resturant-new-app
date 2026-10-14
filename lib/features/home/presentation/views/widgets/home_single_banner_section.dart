import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/features/home/data/banners_list.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';

class HomeSingleBannerSection extends StatelessWidget {
  const HomeSingleBannerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final banner = getBannersList().first;
    return SizedBox(
      height: 164.h,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(
          BannerDetailsPage.routeName,
          arguments: banner,
        ),
        child: BannerImage(banner: banner),
      ),
    );
  }
}
