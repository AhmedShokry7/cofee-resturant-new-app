import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_body.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_bottom_bar.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/quantity_stepper.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<Branch>> activeBranches() async => const [];
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

/// Pumps the full details page: header (title + favorite), content, and the
/// bottom Add to Cart bar, all on the real cubits with mock repositories.
/// The page creates its own [ProductDetailsCubit]; tests read it back from
/// the tree so assertions observe the exact state the UI submits.
Future<void> _pumpDetailsPage(
  WidgetTester tester,
  ProductModel product, {
  required FavoritesCubit favorites,
  required CartCubit cart,
  required BranchCubit branch,
}) {
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: branch),
            BlocProvider.value(value: favorites),
            BlocProvider.value(value: cart),
            RepositoryProvider<CatalogRepository>.value(
              value: MockProductRepository(),
            ),
          ],
          child: ProductDetailsPage(product: product),
        ),
      ),
    ),
  );
}

ProductDetailsCubit _detailsOf(WidgetTester tester) =>
    BlocProvider.of<ProductDetailsCubit>(
      tester.element(find.byType(ProductDetailsBody)),
    );

void main() {
  group('product details skeleton', () {
    testWidgets('mirrors the full-width image plus info column', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 800),
          builder: (context, _) =>
              const MaterialApp(home: Scaffold(body: ProductDetailsSkeleton())),
        ),
      );
      await tester.pump();

      // Edge-to-edge hero: spans the whole 360pt width at 300pt height.
      final hero = tester.getSize(find.byType(ShimmerBox).first);
      expect(hero.width, 360);
      expect(hero.height, 300);
      // Title, price, quantity, description and option groups below it.
      expect(find.byType(ShimmerLine), findsWidgets);
      expect(find.byType(ShimmerBox), findsWidgets);
    });
  });

  group('product details layout', () {
    testWidgets('image spans the full width below the header', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final branch = BranchCubit(repository: _FakeBranchRepository());
      addTearDown(favorites.close);
      addTearDown(cart.close);
      addTearDown(branch.close);

      await _pumpDetailsPage(
        tester,
        product,
        favorites: favorites,
        cart: cart,
        branch: branch,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Header with title + favorite sits above the image (back navigation
      // is provided by the pushing route and is untouched by this change).
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ),
        findsOneWidget,
      );

      // The product image is the first body child and spans edge to edge.
      final imageBox = tester.getSize(
        find
            .descendant(
              of: find.byType(ProductDetailsBody),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(imageBox.width, 360);
      expect(imageBox.height, closeTo(300 * 800 / 690, 1));
    });

    testWidgets('price and quantity live in the content', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final branch = BranchCubit(repository: _FakeBranchRepository());
      addTearDown(favorites.close);
      addTearDown(cart.close);
      addTearDown(branch.close);

      await _pumpDetailsPage(
        tester,
        product,
        favorites: favorites,
        cart: cart,
        branch: branch,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Price with the SAR icon sits in the content next to the title...
      final contentPrices = find.descendant(
        of: find.byType(ProductDetailsBody),
        matching: find.byType(PriceLabel),
      );
      expect(contentPrices, findsWidgets);

      // ...and so does the quantity stepper, starting at 1.
      final stepper = find.descendant(
        of: find.byType(ProductDetailsBody),
        matching: find.byType(QuantityStepper),
      );
      expect(stepper, findsOneWidget);
      expect(
        find.descendant(of: stepper, matching: find.text('1')),
        findsOneWidget,
      );

      // Incrementing updates the same cubit state Add to Cart will submit.
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();
      expect(_detailsOf(tester).state.quantity, 2);
      expect(
        find.descendant(of: stepper, matching: find.text('2')),
        findsOneWidget,
      );

      // The minimum holds: decrementing at 1 stays at 1.
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.remove)),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.remove)),
      );
      await tester.pump();
      expect(_detailsOf(tester).state.quantity, 1);
    });

    testWidgets('bottom bar is Add to Cart only and submits quantity', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final branch = BranchCubit(repository: _FakeBranchRepository());
      addTearDown(favorites.close);
      addTearDown(cart.close);
      addTearDown(branch.close);

      await _pumpDetailsPage(
        tester,
        product,
        favorites: favorites,
        cart: cart,
        branch: branch,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No stepper beside the button anymore.
      expect(
        find.descendant(
          of: find.byType(ProductDetailsBottomBar),
          matching: find.byType(QuantityStepper),
        ),
        findsNothing,
      );

      // Choose 3 in the content, then Add to Cart submits exactly that.
      final stepper = find.descendant(
        of: find.byType(ProductDetailsBody),
        matching: find.byType(QuantityStepper),
      );
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();
      expect(_detailsOf(tester).state.quantity, 3);

      expect(cart.state.count, 0);
      await tester.tap(find.byType(CustomBtn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(cart.state.count, 3);
    });
  });

  group('favorite buttons everywhere', () {
    testWidgets('details header heart fills red when saved', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final product = await _firstProduct();
      final favorites = await _readyFavorites();
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final branch = BranchCubit(repository: _FakeBranchRepository());
      addTearDown(favorites.close);
      addTearDown(cart.close);
      addTearDown(branch.close);

      await _pumpDetailsPage(
        tester,
        product,
        favorites: favorites,
        cart: cart,
        branch: branch,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      Icon headerHeart() => tester.widget<Icon>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Icon)),
      );

      // Idle: outlined heart, existing grey styling.
      expect(headerHeart().icon, HugeIcons.strokeRoundedFavourite);
      expect(headerHeart().color, AppColor.greyColor);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();

      // Saved: completely filled red heart, same persistence as cards.
      expect(headerHeart().icon, Icons.favorite);
      expect(headerHeart().color, AppColor.errorColor);
      expect(favorites.state.ids, contains(product.id));
    });
  });
}
