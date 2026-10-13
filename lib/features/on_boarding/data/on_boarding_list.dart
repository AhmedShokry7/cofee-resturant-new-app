
import 'package:flutter/material.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

List<OnBoardingModel> getOnBoardingList(BuildContext context) {
  return [
    OnBoardingModel(
      image: AppImages.logo,
      title: 'Discover Your Favorites',
      body:
          'Explore a delicious world of coffee and refreshing drinks, all in one place.',
    ),
    OnBoardingModel(
      image: AppImages.logo,
      title: 'Made for Your Mood',
      body:
          'From your morning coffee to your afternoon refreshment, find the perfect drink for every moment.',
    ),
    OnBoardingModel(
      image: AppImages.logo,
      title: 'Your Refreshment, Your Way',
      body:
          'Order your favorite drinks with ease and enjoy every sip, wherever you are.',
    ),
  ];
}