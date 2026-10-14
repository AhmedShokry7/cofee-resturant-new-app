import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/orders_list.dart';

const int _maxRecommendations = 4;

List<ProductModel> getRecommendedProducts() {
  final menu = getMenuList();
  final orderedIds = getOrdersList()
      .map((order) => order.product.id)
      .toSet();

  final result = menu.where((product) => orderedIds.contains(product.id)).toList();

  for (final product in menu) {
    if (result.length >= _maxRecommendations) break;
    if (!result.any((item) => item.id == product.id)) {
      result.add(product);
    }
  }

  return result.take(_maxRecommendations).toList();
}

bool hasOrderHistory() => getOrdersList().isNotEmpty;
