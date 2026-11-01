import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// One slide: its art, its headline and its line of explanation.
class OnBoardingSlide extends StatelessWidget {
  const OnBoardingSlide({super.key, required this.slide});

  final OnBoardingModel slide;

  /// The art is drawn to fill the slide box at this height; the copy always
  /// stays below it, whatever the screen.
  static const double _imageHeight = 350;

  /// Gap between the art and the headline. The headline is the second thing
  /// the eye lands on, so it sits further away than a spacing step.
  static const double _artGap = 40;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: AppSpacing.lg),
        // The words come first: when a slide needs more height than the box
        // has, the art gives way instead of the copy being cut. At the design
        // size the art was drawn for, this shortfall is a single pixel.
        Flexible(
          child: Image.asset(
            slide.image,
            height: _imageHeight,
            fit: BoxFit.fill,
          ),
        ),
        SizedBox(height: _artGap),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: AppFonts.semiBold24(context)
              .copyWith(color: AppColor.primaryColor),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          slide.body,
          textAlign: TextAlign.center,
          style: AppFonts.regular16(context)
              .copyWith(color: AppColor.greyColor),
        ),
      ],
    );
  }
}
