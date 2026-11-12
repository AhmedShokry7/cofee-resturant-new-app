import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

import 'support/fake_design_repository.dart';
import 'support/mock_product_repository.dart';
import 'support/pump_harness.dart';

import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_favorite_button.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

class _FakeWeatherRepository implements WeatherRepository {
  @override
  Future<WeatherModel> getCurrentWeather() async =>
      const WeatherModel(temperature: 32);
}

/// The home tab reads the signed-in customer for its greeting; these tests are
/// about the FAB and the product cards, so the session stays empty.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

/// Disposes the tree so the FAB's cubit cannot outlive the test.
Future<void> _disposeFab(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<ProductModel> _firstProduct() async {
  final products = await MockProductRepository().getProducts();
  return products.first;
}

Future<FavoritesCubit> _readyFavorites() async {
  final cubit = FavoritesCubit(
    repository: MockProductRepository(),
    favorites: FavoritesRepositoryImpl(),
  );
  await cubit.stream.firstWhere((state) => !state.isLoading);
  return cubit;
}

void main() {
  group('assistant FAB', () {
    testWidgets('is a proper elevated circular FAB with the bot icon', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      await _pump(tester, const Scaffold(floatingActionButton: AssistantFab()));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.shape, isA<CircleBorder>());
      expect(fab.backgroundColor, AppColor.whiteColor);
      expect(fab.elevation, 6);
      expect(find.byKey(const ValueKey('assistant_fab_image')), findsOneWidget);

      // Fully inside the phone surface: no overflow, no clipped button.
      final surface = Offset.zero & const Size(360, 800);
      final rect = tester.getRect(find.byType(FloatingActionButton));
      expect(surface.contains(rect.topLeft), isTrue);
      expect(surface.contains(rect.bottomRight), isTrue);

      await _disposeFab(tester);
    });

    testWidgets('home page owns the FAB in its scaffold slot', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final catalog = MockProductRepository();
      final home = HomeCubit(repository: catalog);
      final weather = WeatherCubit(_FakeWeatherRepository());
      final favorites = await _readyFavorites();
      addTearDown(home.close);
      addTearDown(weather.close);
      addTearDown(favorites.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: home),
              BlocProvider.value(value: weather),
              BlocProvider.value(value: favorites),
              BlocProvider(
                create: (_) => DesignCubit(repository: FakeDesignRepository()),
              ),
            ],
            child: RepositoryProvider<AuthRepository>.value(
              value: _FakeAuthRepository(),
              child: const HomePage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AssistantFab), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButton, isA<AssistantFab>());

      await _disposeFab(tester);
    });

    testWidgets('categories page shows no assistant FAB', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final catalog = MockProductRepository();
      final categories = CategoriesCubit(repository: catalog);
      final favorites = await _readyFavorites();
      addTearDown(categories.close);
      addTearDown(favorites.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: categories),
              BlocProvider.value(value: favorites),
            ],
            child: const CategoriesPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AssistantFab), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('product card height', () {
    testWidgets('card keeps the taller shared aspect ratio', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: favorites,
              child: SizedBox(width: 170, child: ProductCard(product: product)),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(ProductCard.cardAspectRatio, 0.60);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        ProductCard.cardAspectRatio,
      );
      // The subtitle line shows the product category (Espresso's row
      // carries "Hot Coffee"), falling back to the description only when
      // the row has no category.
      expect(find.text('Hot Coffee'), findsOneWidget);
      // Taller than the previous 0.75 card at the same width.
      final size = tester.getSize(find.byType(ProductCard));
      expect(size.height, closeTo(170 / ProductCard.cardAspectRatio, 1));
      expect(size.height, greaterThan(170 / 0.75));
    });

    testWidgets('grid delegate matches the card aspect ratio', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final catalog = MockProductRepository();
      final products = await catalog.getProducts();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: favorites,
              child: ProductsGridView(products: products),
            ),
          ),
        ),
      );
      await tester.pump();

      final sliver = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          sliver.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, AppBreakpoints.productCardMaxWidth);
      expect(delegate.childAspectRatio, ProductCard.cardAspectRatio);

      // Two cards share a phone row...
      expect(columnCount(find.byType(ProductCard)), 2);

      // ...and a wide window gains columns instead of fat cards. The window
      // itself has to grow: a child wider than the surface is clamped to it,
      // so the grid would still see a phone.
      tester.view.physicalSize = tabletViewport * phoneDevicePixelRatio;
      await tester.pump();
      expect(columnCount(find.byType(ProductCard)), greaterThan(2));
    });

    testWidgets('carousel strip fits the taller cards exactly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final catalog = MockProductRepository();
      final products = (await catalog.getProducts()).take(4).toList();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: favorites,
              child: SizedBox(
                width: 360,
                height: 500,
                child: HomeProductsCarousel(
                  title: 'Popular',
                  products: products,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final strip = tester.getSize(find.byType(ListView));
      expect(strip.height, closeTo(168 / ProductCard.cardAspectRatio, 1));
      expect(find.byType(ProductCard), findsWidgets);
    });
  });

  group('favorite button', () {
    testWidgets('toggles outline/active filled states and persists', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await _pump(
        tester,
        BlocProvider.value(
          value: favorites,
          child: ProductFavoriteButton(product: product),
        ),
      );
      await tester.pump();

      Icon icon() => tester.widget<Icon>(find.byType(Icon));

      // Inactive: outlined heart in grey, existing styling untouched.
      expect(icon().icon, AppIcons.favourite);
      expect(icon().color, AppColor.greyColor);

      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.pumpAndSettle();

      // Active: unmistakable filled red heart (the heart itself is the
      // colour, not the circle around it).
      expect(icon().icon, Icons.favorite);
      expect(icon().color, AppColor.errorColor);

      // Persisted to the same guest store the app already uses.
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('favorites_v1_guest')!), [product.id]);

      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.pumpAndSettle();

      expect(icon().icon, AppIcons.favourite);
      expect(icon().color, AppColor.greyColor);
      expect(jsonDecode(prefs.getString('favorites_v1_guest')!), isEmpty);
    });

    testWidgets('rapid taps do not duplicate or corrupt state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await _pump(
        tester,
        BlocProvider.value(
          value: favorites,
          child: ProductFavoriteButton(product: product),
        ),
      );
      await tester.pump();

      // Fire three toggles without settling: only the first runs.
      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.pumpAndSettle();

      expect(favorites.state.ids, {product.id});
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('favorites_v1_guest')!), [product.id]);
    });
  });
}
