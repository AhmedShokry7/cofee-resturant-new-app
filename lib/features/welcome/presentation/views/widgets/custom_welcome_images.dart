import 'package:flutter/material.dart';
import 'package:new_coffee/core/constant/app_images.dart';

class CustomWelcomeImages extends StatelessWidget {
  const CustomWelcomeImages({super.key});

  @override
  Widget build(BuildContext context) {
    return Image(
      image: const AssetImage(AppImages.welcomeImage),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
