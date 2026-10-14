import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// Drink sizes. [priceDelta] is added to the base price (same currency as
/// the menu). Tune the deltas here when the real menu pricing arrives.
enum DrinkSize {
  small('Small', 'S', 0),
  medium('Medium', 'M', 5),
  large('Large', 'L', 10);

  const DrinkSize(this.label, this.shortLabel, this.priceDelta);

  final String label;
  final String shortLabel;
  final double priceDelta;

  static DrinkSize? fromName(String? name) {
    if (name == null) return null;
    final normalized = name.trim().toLowerCase();
    for (final size in DrinkSize.values) {
      if (size.name == normalized) return size;
    }
    return null;
  }
}

/// Free sugar preference (no price effect, stored in the cart note).
enum SugarLevel {
  none('No Sugar'),
  less('Less Sugar'),
  normal('Regular'),
  extra('Extra Sugar');

  const SugarLevel(this.label);

  final String label;

  static SugarLevel? fromName(String? name) {
    if (name == null) return null;
    final normalized = name.trim().toLowerCase();
    for (final level in SugarLevel.values) {
      if (level.name == normalized) return level;
    }
    return null;
  }
}

/// Paid add-on for drinks.
class ProductExtra {
  const ProductExtra({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final double price;
}

/// Categories served in cups (sizes + sugar + extras apply).
const Set<String> sizedCategories = {
  'Hot Coffee',
  'Cold Coffee',
  'Tea',
  'Milkshakes',
  'Soft Drinks',
};

bool hasSizes(ProductModel product) => sizedCategories.contains(product.category);

bool hasSugarChoice(ProductModel product) =>
    sizedCategories.contains(product.category);

/// Paid extras per category. Categories absent here have no extras.
const Map<String, List<ProductExtra>> _extrasByCategory = {
  'Hot Coffee': [
    ProductExtra(id: 'shot', name: 'Extra Espresso Shot', price: 8),
    ProductExtra(id: 'cream', name: 'Whipped Cream', price: 5),
    ProductExtra(id: 'vanilla', name: 'Vanilla Syrup', price: 5),
    ProductExtra(id: 'caramel', name: 'Caramel Syrup', price: 5),
  ],
  'Cold Coffee': [
    ProductExtra(id: 'shot', name: 'Extra Espresso Shot', price: 8),
    ProductExtra(id: 'cream', name: 'Whipped Cream', price: 5),
    ProductExtra(id: 'vanilla', name: 'Vanilla Syrup', price: 5),
    ProductExtra(id: 'caramel', name: 'Caramel Syrup', price: 5),
  ],
  'Tea': [
    ProductExtra(id: 'mint', name: 'Fresh Mint', price: 3),
    ProductExtra(id: 'honey', name: 'Honey', price: 5),
  ],
  'Milkshakes': [
    ProductExtra(id: 'cream', name: 'Whipped Cream', price: 5),
    ProductExtra(id: 'scoop', name: 'Extra Ice Cream Scoop', price: 10),
  ],
};

List<ProductExtra> extrasFor(ProductModel product) =>
    _extrasByCategory[product.category] ?? const [];

/// "Goes well with": which categories complement each category.
const Map<String, List<String>> _pairingCategories = {
  'Hot Coffee': ['Desserts', 'Snacks', 'Bakery', 'Donuts'],
  'Cold Coffee': ['Desserts', 'Snacks', 'Donuts'],
  'Tea': ['Desserts', 'Bakery', 'Snacks'],
  'Milkshakes': ['Donuts', 'Desserts'],
  'Soft Drinks': ['Snacks', 'Desserts'],
  'Desserts': ['Hot Coffee', 'Cold Coffee', 'Tea'],
  'Snacks': ['Hot Coffee', 'Cold Coffee', 'Soft Drinks'],
  'Bakery': ['Hot Coffee', 'Tea'],
  'Donuts': ['Hot Coffee', 'Milkshakes'],
};

/// Products that go well with [product] (same list drives the details page
/// section and the bot's pairing suggestions). Never includes itself.
List<ProductModel> pairingsFor(ProductModel product, {int limit = 6}) {
  final menu = getMenuList();
  final targets = _pairingCategories[product.category] ?? const [];
  final paired = menu
      .where(
        (item) =>
            item.id != product.id && targets.contains(item.category),
      )
      .toList();
  if (paired.isNotEmpty) return paired.take(limit).toList();
  // Fallback: same-category neighbours when no pairing is configured.
  return menu.where((item) => item.id != product.id).take(limit).toList();
}

/// One configured unit price: base + size + extras.
double unitPrice(
  ProductModel product, {
  DrinkSize? size,
  Iterable<ProductExtra> extras = const [],
}) {
  var total = product.price + (size?.priceDelta ?? 0);
  for (final extra in extras) {
    total += extra.price;
  }
  return total;
}

/// Cart-note summary, e.g. "Large, Less Sugar, Whipped Cream".
String variantNote({
  DrinkSize? size,
  SugarLevel? sugar,
  Iterable<ProductExtra> extras = const [],
}) {
  final parts = <String>[
    if (size != null) size.label,
    if (sugar != null && sugar != SugarLevel.normal) sugar.label,
    ...extras.map((extra) => extra.name),
  ];
  return parts.join(', ');
}
