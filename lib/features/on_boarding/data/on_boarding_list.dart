import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

/// The intro slides the first launch shows.
///
/// The copy lives in [S] like every other label, so the language toggle flips
/// the onboarding with the rest of the app.
List<OnBoardingModel> onBoardingSlides() => [
  OnBoardingModel(
    image: AppImages.onboardingImage1,
    title: S.onBoardingCatalogTitle,
    body: S.onBoardingCatalogBody,
  ),
  OnBoardingModel(
    image: AppImages.onboardingImage2,
    title: S.onBoardingPaymentTitle,
    body: S.onBoardingPaymentBody,
  ),
  OnBoardingModel(
    image: AppImages.onboardingImage3,
    title: S.onBoardingAssistantTitle,
    body: S.onBoardingAssistantBody,
  ),
];
