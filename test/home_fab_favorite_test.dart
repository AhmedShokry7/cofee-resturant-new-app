import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
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

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

/// Lets the assistant FAB's one-shot hint timers fire, then disposes the
/// tree so its periodic hint cycle cannot outlive the test.
Future<void> _disposeFab(WidgetTester tester) async {
  await tester.pump(AssistantFab.hintCycle);
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
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: home),
                BlocProvider.value(value: weather),
                BlocProvider.value(value: favorites),
              ],
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
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: categories),
                BlocProvider.value(value: favorites),
              ],
              child: const CategoriesPage(),
            ),
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
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(
                value: favorites,
                child: SizedBox(
                  width: 170,
                  child: ProductCard(product: product),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(ProductCard.cardAspectRatio, 0.64);
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        ProductCard.cardAspectRatio,
      );
      // ~12.5% taller than the old 0.72 card at the same width.
      final size = tester.getSize(find.byType(ProductCard));
      expect(size.height, closeTo(170 / 0.64, 1));
      expect(size.height, greaterThan(170 / 0.72));
    });

    testWidgets('grid delegate matches the card aspect ratio', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final catalog = MockProductRepository();
      final products = await catalog.getProducts();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(
                value: favorites,
                child: SizedBox(
                  width: 360,
                  height: 800,
                  child: ProductsGridView(products: products),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final sliver = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          sliver.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(delegate.childAspectRatio, ProductCard.cardAspectRatio);
    });

    testWidgets('carousel strip fits the taller cards exactly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final catalog = MockProductRepository();
      final products = (await catalog.getProducts()).take(4).toList();
      final favorites = await _readyFavorites();
      addTearDown(favorites.close);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
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
        ),
      );
      await tester.pump();

      final strip = tester.getSize(find.byType(ListView));
      expect(strip.height, closeTo(150 / 0.64, 1));
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
      expect(icon().icon, HugeIcons.strokeRoundedFavourite);
      expect(icon().color, AppColor.greyColor);

      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.pumpAndSettle();

      // Active: unmistakable filled red heart.
      expect(icon().icon, Icons.favorite);
      expect(icon().color, AppColor.errorColor);

      // Persisted to the same guest store the app already uses.
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('favorites_v1_guest')!), [product.id]);

      await tester.tap(find.byType(ProductFavoriteButton));
      await tester.pumpAndSettle();

      expect(icon().icon, HugeIcons.strokeRoundedFavourite);
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
