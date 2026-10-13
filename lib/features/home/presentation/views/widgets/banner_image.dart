import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/features/home/data/model/banner_model.dart';

class BannerImage extends StatelessWidget {
  const BannerImage({super.key, required this.banner, this.borderRadius = 8});

  final BannerModel banner;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius.r),
        image: DecorationImage(
          image: AssetImage(banner.image),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
