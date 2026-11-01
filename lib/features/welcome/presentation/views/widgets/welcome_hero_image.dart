import 'package:flutter/material.dart';

import 'package:new_coffee/core/constant/app_images.dart';

/// The photograph behind the welcome copy.
///
/// The visible subject sits in the top of the file, so the crop keeps it in
/// frame when the panel covers the bottom of a tall screen.
class WelcomeHeroImage extends StatelessWidget {
  const WelcomeHeroImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Image(
      image: const AssetImage(AppImages.welcomeImage),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
