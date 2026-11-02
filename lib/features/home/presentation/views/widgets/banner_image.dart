import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class BannerImage extends StatelessWidget {
  const BannerImage({
    super.key,
    required this.banner,
    this.borderRadius = AppRadius.r8,
  });
  final BannerModel banner;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => DbImage(
    image: banner.image,
    // Every banner slot is wider than the 16:9 pictures the dashboard uploads,
    // so `cover` cropped their top and bottom. `fill` shows the whole picture.
    fit: BoxFit.fill,
    width: double.infinity,
    height: double.infinity,
    borderRadius: BorderRadius.circular(borderRadius),
  );
}
