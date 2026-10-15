import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

const List<OnBoardingModel> onBoardingSlides = [
  OnBoardingModel(
    title: 'مرحباً بك في تطبيق القهوة',
    body: 'اكتشف أفضل المشروبات والمناسبات المميزة',
    image: AppImages.onBoarding1,
  ),
  OnBoardingModel(
    title: 'اختر مشروبك المفضل',
    body: 'تصفح القائمة وتمتع بعروض حصرية',
    image: AppImages.onBoarding2,
  ),
  OnBoardingModel(
    title: 'قم بالطلب بكل سهولة',
    body: 'اختصر الخطوات وادفع عند الاستلام',
    image: AppImages.onBoarding3,
  ),
];