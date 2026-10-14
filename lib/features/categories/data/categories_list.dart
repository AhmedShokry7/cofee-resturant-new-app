import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/features/categories/data/model/category_model.dart';

List<CategoryModel> getCategoriesList() {
  return const [
    CategoryModel(label: "Hot Coffee", icon: HugeIcons.strokeRoundedCoffee01),
    CategoryModel(label: "Cold Coffee", icon: HugeIcons.strokeRoundedDrink),
    CategoryModel(label: "Tea", icon: HugeIcons.strokeRoundedTea),
    CategoryModel(label: "Desserts", icon: HugeIcons.strokeRoundedCupcake01),
    CategoryModel(label: "Snacks", icon: HugeIcons.strokeRoundedCookie),
    CategoryModel(
      label: "Milkshakes",
      icon: HugeIcons.strokeRoundedMilkBottle,
    ),
    CategoryModel(
      label: "Soft Drinks",
      icon: HugeIcons.strokeRoundedSoftDrink01,
    ),
    CategoryModel(label: "Bakery", icon: HugeIcons.strokeRoundedBread01),
    CategoryModel(label: "Donuts", icon: HugeIcons.strokeRoundedDoughnut),
    CategoryModel(label: "Bundles", icon: HugeIcons.strokeRoundedPackage),
  ];
}
