import 'package:flutter/material.dart';

import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class BannerImage extends StatelessWidget {
  const BannerImage({super.key, required this.banner, this.borderRadius = 8});

  final BannerModel banner;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => DbImage(
    image: banner.image,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    borderRadius: BorderRadius.circular(borderRadius),
  );
}
