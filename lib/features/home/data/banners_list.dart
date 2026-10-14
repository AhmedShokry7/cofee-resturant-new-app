import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';

List<BannerModel> getBannersList() {
  return const [
    BannerModel(
      id: "1",
      image: AppImages.banner,
      title: "Morning Boost",
      subtitle: "Start your day the right way",
      description:
          "Kick off your morning with our rich Hot Coffee picks. Bold espresso shots, creamy cappuccinos and smooth lattes, brewed fresh to fuel your whole day.",
      ctaLabel: "Shop Hot Coffee",
      targetCategory: "Hot Coffee",
    ),
    BannerModel(
      id: "2",
      image: AppImages.banner,
      title: "Iced & Fresh",
      subtitle: "Cool down with every sip",
      description:
          "Beat the heat with our chilled Cold Coffee selection. Iced lattes and frosty favorites, served over plenty of ice for maximum refreshment.",
      ctaLabel: "Shop Cold Coffee",
      targetCategory: "Cold Coffee",
    ),
    BannerModel(
      id: "3",
      image: AppImages.banner,
      title: "Tea Time",
      subtitle: "Calm in every cup",
      description:
          "Unwind with our soothing Tea collection. From antioxidant-rich Green Tea to warm spiced Masala Tea, there is a calm moment waiting for you.",
      ctaLabel: "Shop Tea",
      targetCategory: "Tea",
    ),
    BannerModel(
      id: "4",
      image: AppImages.banner,
      title: "Sweet Treats",
      subtitle: "Dessert lovers, this is for you",
      description:
          "Indulge your sweet tooth with our Desserts lineup. Creamy cheesecakes and fudgy brownies that pair perfectly with any coffee.",
      ctaLabel: "Shop Desserts",
      targetCategory: "Desserts",
    ),
    BannerModel(
      id: "5",
      image: AppImages.banner,
      title: "Snack Corner",
      subtitle: "Little bites, big flavor",
      description:
          "Grab a quick bite from our Snacks shelf. Freshly baked cookies and golden croissants, made to go perfectly with your favorite drink.",
      ctaLabel: "Shop Snacks",
      targetCategory: "Snacks",
    ),
  ];
}
