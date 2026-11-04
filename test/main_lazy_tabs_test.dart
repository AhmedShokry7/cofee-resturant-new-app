import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/cart/presentation/views/cart_page.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/views/favorites_page.dart';

import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_scoped_header.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';

import 'package:new_coffee/features/categories/data/model/category_model.dart';

import 'support/fake_design_repository.dart';
import 'support/mock_product_repository.dart';

import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<Branch>> activeBranches() async => const [];
}

class _FakeWeatherRepository implements WeatherRepository {
  @override
  Future<WeatherModel> getCurrentWeather() async =>
      const WeatherModel(temperature: 25);
}

/// The home tab reads the signed-in customer for its greeting; this test is
/// about which tabs get built, so the session stays empty.
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

class _CountingCatalog extends MockProductRepository {
  int categoryLoads = 0;
  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async {
    categoryLoads++;
    return super.getCategories(includeInactive: includeInactive);
  }
}

void main() {
  testWidgets('inactive tabs are not built until visited', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    final catalog = MockProductRepository();
    final home = HomeCubit(repository: catalog);
    final weather = WeatherCubit(_FakeWeatherRepository());
    final categories = CategoriesCubit(repository: catalog);
    final cart = CartCubit(
      cartRepository: LocalCartRepository(),
      catalogRepository: catalog,
    );
    final favorites = FavoritesCubit(
      repository: catalog,
      favorites: FavoritesRepositoryImpl(userIdProvider: () => null),
    );
    final branch = BranchCubit(repository: _FakeBranchRepository());

    addTearDown(home.close);
    addTearDown(weather.close);
    addTearDown(categories.close);
    addTearDown(cart.close);
    addTearDown(favorites.close);
    addTearDown(branch.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: branch),
            BlocProvider.value(value: cart),
            BlocProvider.value(value: favorites),
            BlocProvider.value(value: weather),
            BlocProvider.value(value: home),
            BlocProvider.value(value: categories),
            BlocProvider(
              create: (_) => DesignCubit(repository: FakeDesignRepository()),
            ),
          ],
          child: RepositoryProvider<AuthRepository>.value(
            value: _FakeAuthRepository(),
            child: const MainPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MainPage), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(CategoriesPage), findsNothing);
    expect(find.byType(CartPage), findsNothing);
    expect(find.byType(FavoritesPage), findsNothing);

    await tester.tap(find.byIcon(AppIcons.grid).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CategoriesPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('initialCategoryId shows that category alone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    final catalog = MockProductRepository();
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [BlocProvider.value(value: cubit)],
          child: const CategoriesPage(initialCategoryId: 'tea'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(cubit.state.categories, isNotEmpty);
    expect(
      find.byType(CategoryTabs),
      findsNothing,
      reason: 'a page asked for one category has no other categories to pick',
    );
    expect(
      find.descendant(
        of: find.byType(CategoryScopedHeader),
        matching: find.text('Tea'),
      ),
      findsOneWidget,
    );
    expect(
      cubit.state.index,
      0,
      reason: 'the catalogue tab keeps whatever the customer had open',
    );
  });

  test('ensureLoaded does not reload on repeated calls', () async {
    final catalog = _CountingCatalog();
    final cubit = CategoriesCubit(repository: catalog);
    cubit.ensureLoaded();
    await cubit.stream.firstWhere((state) => !state.isLoading);
    final first = catalog.categoryLoads;

    cubit.ensureLoaded();

    expect(first, greaterThan(0));
    expect(catalog.categoryLoads, first);
    await cubit.close();
  });
}
