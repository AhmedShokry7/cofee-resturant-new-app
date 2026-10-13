import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';

List<BannerModel> getBannersList() {
  return const [
    BannerModel(id: "1", image: AppImages.banner),
    BannerModel(id: "2", image: AppImages.banner),
    BannerModel(id: "3", image: AppImages.banner),
    BannerModel(id: "4", image: AppImages.banner),
    BannerModel(id: "5", image: AppImages.banner),
  ];
}
