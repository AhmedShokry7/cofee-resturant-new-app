import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';

import 'support/mock_product_repository.dart';

import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';

/// The card must show the whole price. When a product is discounted the row
/// holds the live price, the currency symbol and the struck-through old price;
/// the live price used to be squeezed to zero width and disappear.
Future<void> _pumpCard(WidgetTester tester, ProductCard card) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(360, 800) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final favorites = FavoritesCubit(
    repository: MockProductRepository(),
    favorites: FavoritesRepositoryImpl(),
  );
  addTearDown(favorites.close);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: CartCubit(
              cartRepository: LocalCartRepository(),
              catalogRepository: MockProductRepository(),
            ),
          ),
          BlocProvider.value(value: favorites),
        ],
        child: Scaffold(
          body: SizedBox(width: ProductCard.stripWidth, child: card),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// True when the text had to be shortened to fit its box.
bool _isTruncated(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.didExceedMaxLines;
}

void main() {
  testWidgets('a discounted card shows the live price in full', (tester) async {
    final products = await MockProductRepository().getProducts();
    final discounted = products.firstWhere((p) => p.hasDiscount);

    await _pumpCard(tester, ProductCard(product: discounted));

    // The live price and the old price are both on screen...
    expect(find.text(discounted.price.toStringAsFixed(2)), findsOneWidget);
    expect(find.text(discounted.oldPrice!.toStringAsFixed(2)), findsOneWidget);
    // ...and the live price is not cut short.
    expect(_isTruncated(tester, discounted.price.toStringAsFixed(2)), isFalse);
  });

  testWidgets('a discounted card shows two prices and no percentage', (
    tester,
  ) async {
    // The corner badge used to repeat this pair as a percentage. The card
    // keeps the money: what the customer pays and, struck through, what the
    // product cost before the discount.
    final products = await MockProductRepository().getProducts();
    final discounted = products.firstWhere((p) => p.hasDiscount);

    await _pumpCard(tester, ProductCard(product: discounted));

    expect(find.text(discounted.price.toStringAsFixed(2)), findsOneWidget);
    expect(find.text(discounted.oldPrice!.toStringAsFixed(2)), findsOneWidget);
    expect(
      find.textContaining('%'),
      findsNothing,
      reason: 'no percentage mark is left on a card',
    );
  });

  testWidgets('a plain card shows the price in full', (tester) async {
    final products = await MockProductRepository().getProducts();
    final plain = products.firstWhere((p) => !p.hasDiscount);

    await _pumpCard(tester, ProductCard(product: plain));

    expect(find.text(plain.price.toStringAsFixed(2)), findsOneWidget);
    expect(_isTruncated(tester, plain.price.toStringAsFixed(2)), isFalse);
  });

  testWidgets('a cart card shows the piece price beside the add button', (
    tester,
  ) async {
    final products = await MockProductRepository().getProducts();
    final product = products.firstWhere((p) => !p.hasDiscount);
    const quantity = 3;

    await _pumpCartCard(
      tester,
      ProductCard(product: product, quantity: quantity),
    );

    // The price of one piece sits next to the add button...
    expect(find.text(product.price.toStringAsFixed(2)), findsOneWidget);
    // ...and the line total stays where it was.
    expect(
      find.text((product.price * quantity).toStringAsFixed(2)),
      findsOneWidget,
    );
    // The add button is still there.
    expect(find.byIcon(AppIcons.add), findsOneWidget);
  });
}

/// Pumps a cart card the way the cart page does: full width, inside a list.
Future<void> _pumpCartCard(WidgetTester tester, ProductCard card) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(360, 800) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final favorites = FavoritesCubit(
    repository: MockProductRepository(),
    favorites: FavoritesRepositoryImpl(),
  );
  addTearDown(favorites.close);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: CartCubit(
              cartRepository: LocalCartRepository(),
              catalogRepository: MockProductRepository(),
            ),
          ),
          BlocProvider.value(value: favorites),
        ],
        child: Scaffold(body: ListView(children: [card])),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
