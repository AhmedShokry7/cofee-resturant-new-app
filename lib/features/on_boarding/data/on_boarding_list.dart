
import 'package:flutter/material.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

List<OnBoardingModel> getOnBoardingList(BuildContext context) {
  final isArabic = AppLocale.instance.isArabic;

  return [
    OnBoardingModel(
      image: AppImages.onboardingImage1,
      title: isArabic ? 'كل ما تحب في مكان واحد' : 'Everything You Love, in One Place',
      body: isArabic
          ? 'اكتشف القهوة والمشروبات ومنتجاتك المفضلة بسهولة.'
          : 'Explore coffee, drinks, and your favorite products with ease.',
    ),
    OnBoardingModel(
      image: AppImages.onboardingImage2,
      title: isArabic ? 'ادفع بالطريقة التي تناسبك' : 'Pay Your Way',
      body: isArabic
          ? 'استمتع بتجربة دفع سهلة وآمنة لإكمال طلبك بكل راحة.'
          : 'Enjoy a smooth and secure payment experience every time you order.',
    ),
    OnBoardingModel(
      image: AppImages.onboardingImage3,
      title: isArabic ? 'مساعدك الذكي معك دائمًا' : 'Meet Your AI Assistant',
      body: isArabic
          ? 'احصل على اقتراحات ذكية واكتشف ما يناسب ذوقك بسهولة.'
          : 'Get smart recommendations and discover what matches your taste.',
    ),
  ];
}