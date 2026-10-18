import 'package:flutter/material.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

List<OnBoardingModel> getOnBoardingList(BuildContext context) {
  final isArabic = AppLocale.instance.isArabic;
  return [
    OnBoardingModel(
      image: AppImages.logo,
      title: isArabic ? 'مرحباً بك' : 'Welcome',
      body: isArabic ? 'اكتشف أفضل القهوة والمشروبات.' : 'Discover the best coffee and drinks.',
    ),
    OnBoardingModel(
      image: AppImages.logo,
      title: isArabic ? 'اطلب بسهولة' : 'Order easily',
      body: isArabic ? 'اختر منتجاتك وأكمل الطلب بسرعة.' : 'Choose your products and complete your order quickly.',
    ),
    OnBoardingModel(
      image: AppImages.logo,
      title: isArabic ? 'توصيل سريع' : 'Fast delivery',
      body: isArabic ? 'نحن نوصل طلبك إلى بابك.' : 'We deliver your order to your door.',
    ),
  ];
}
