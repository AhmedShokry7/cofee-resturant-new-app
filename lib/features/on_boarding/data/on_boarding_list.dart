import 'package:flutter/material.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

List<OnBoardingModel> getOnBoardingList(BuildContext context) {
  return [
    OnBoardingModel(
      image: AppImages.logo,
      title: "S.of(context).onboarding_title_1",
      body: "S.of(context).onboarding_subtitle_1",
    ),
    OnBoardingModel(
      image: AppImages.logo,
      title: "S.of(context).onboarding_title_2",
      body: "S.of(context).onboarding_subtitle_2",
    ),
    OnBoardingModel(
      image: AppImages.logo,
      title: "S.of(context).onboarding_title_3",
      body: "S.of(context).onboarding_subtitle_3",
    ),
  ];
}
