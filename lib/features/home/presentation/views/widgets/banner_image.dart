import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';

class BannerImage extends StatelessWidget {
  const BannerImage({super.key, required this.banner, this.borderRadius = 8});

  final BannerModel banner;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = banner.image.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius.r),
      child: image.isEmpty
          ? const _UnavailableBannerImage()
          : image.startsWith('http://') || image.startsWith('https://')
          ? Image.network(
              image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _UnavailableBannerImage(),
            )
          : Image.asset(
              image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _UnavailableBannerImage(),
            ),
    );
  }
}

class _UnavailableBannerImage extends StatelessWidget {
  const _UnavailableBannerImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColor.surfaceColor,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppColor.greyColor,
      ),
    ),
  );
}
