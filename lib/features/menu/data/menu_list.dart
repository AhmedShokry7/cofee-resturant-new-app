import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

List<ProductModel> getMenuList() {
  return const [
    ProductModel(
      id: "1",
      name: "Espresso",
      category: "Hot Coffee",
      description:
          "A rich and bold single shot of pure espresso, made from freshly ground premium beans. Served hot with a thick golden crema on top for a smooth, intense coffee experience.",
      price: 25,
      image: AppImages.product,
    ),
    ProductModel(
      id: "2",
      name: "Cappuccino",
      category: "Hot Coffee",
      description:
          "A classic favorite made with a balanced shot of espresso, topped with steamed milk and a generous layer of velvety milk foam. Perfect for any time of the day.",
      price: 40,
      oldPrice: 50,
      image: AppImages.product,
    ),
    ProductModel(
      id: "3",
      name: "Latte",
      category: "Hot Coffee",
      description:
          "Smooth espresso blended with plenty of steamed milk for a creamy, mellow flavor. Finished with a light layer of foam and a touch of natural sweetness.",
      price: 35,
      image: AppImages.product,
    ),
    ProductModel(
      id: "4",
      name: "Mocha",
      category: "Hot Coffee",
      description:
          "A decadent combination of rich espresso, steamed milk and premium chocolate syrup, topped with whipped cream. The perfect treat for chocolate and coffee lovers alike.",
      price: 45,
      oldPrice: 55,
      image: AppImages.product,
    ),
    ProductModel(
      id: "5",
      name: "Americano",
      category: "Hot Coffee",
      description:
          "Espresso diluted with hot water to create a lighter, smoother cup that keeps all the rich aroma of the beans. A clean and refreshing choice for everyday coffee.",
      price: 30,
      image: AppImages.product,
    ),
    ProductModel(
      id: "6",
      name: "Iced Latte",
      category: "Cold Coffee",
      description:
          "Chilled espresso poured over ice and combined with cold fresh milk for a refreshing, creamy drink. The ideal cool-down on a warm and sunny day.",
      price: 42,
      oldPrice: 50,
      image: AppImages.product,
    ),
    ProductModel(
      id: "7",
      name: "Green Tea",
      category: "Tea",
      description:
          "A light and refreshing green tea brewed from premium leaves, rich in antioxidants and perfect for a calm moment any time of the day.",
      price: 20,
      image: AppImages.product,
    ),
    ProductModel(
      id: "8",
      name: "Masala Tea",
      category: "Tea",
      description:
          "A warm spiced tea blended with milk, cardamom, ginger and cinnamon for a comforting and aromatic cup.",
      price: 25,
      image: AppImages.product,
    ),
    ProductModel(
      id: "9",
      name: "Cheesecake",
      category: "Desserts",
      description:
          "A rich and creamy cheesecake with a buttery biscuit base, baked to perfection and served chilled.",
      price: 55,
      oldPrice: 65,
      image: AppImages.product,
    ),
    ProductModel(
      id: "10",
      name: "Chocolate Brownie",
      category: "Desserts",
      description:
          "A warm, fudgy chocolate brownie made with premium cocoa, served soft in the middle with a rich chocolate flavor.",
      price: 48,
      image: AppImages.product,
    ),
    ProductModel(
      id: "11",
      name: "Chocolate Chip Cookie",
      category: "Snacks",
      description:
          "A freshly baked cookie loaded with melting chocolate chips. Crisp on the edges and soft in the center.",
      price: 18,
      image: AppImages.product,
    ),
    ProductModel(
      id: "12",
      name: "Butter Croissant",
      category: "Snacks",
      description:
          "A golden, flaky and buttery croissant baked fresh every morning. The perfect snack with your coffee.",
      price: 30,
      image: AppImages.product,
    ),
    ProductModel(
      id: "13",
      name: "Chocolate Milkshake",
      category: "Milkshakes",
      description:
          "A thick and creamy chocolate milkshake blended with premium ice cream and topped with whipped cream.",
      price: 45,
      oldPrice: 55,
      image: AppImages.product,
    ),
    ProductModel(
      id: "14",
      name: "Cola",
      category: "Soft Drinks",
      description:
          "A chilled glass of refreshing cola served over ice. The perfect fizzy companion to any meal.",
      price: 15,
      image: AppImages.product,
    ),
    ProductModel(
      id: "15",
      name: "Butter Bread",
      category: "Bakery",
      description:
          "A freshly baked loaf of soft butter bread, perfect for breakfast or a light snack.",
      price: 28,
      image: AppImages.product,
    ),
    ProductModel(
      id: "16",
      name: "Glazed Donut",
      category: "Donuts",
      description:
          "A soft and fluffy donut coated with a sweet glossy glaze. A classic treat for any time of the day.",
      price: 22,
      image: AppImages.product,
    ),
  ];
}
