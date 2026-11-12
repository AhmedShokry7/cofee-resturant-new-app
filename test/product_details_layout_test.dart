import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/bundles/presentation/manager/bundle_details/bundle_details_cubit.dart';
import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

import 'support/mock_product_repository.dart';

import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_body.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_bottom_bar.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/quantity_stepper.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
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

/// Pumps the full details page - header (title + favourite), content, and the
/// bottom Add to Cart bar - on fresh cubits, and returns them so a test can
/// assert against the same cart/favourites the UI writes to. The page creates
/// its own [ProductDetailsCubit]; [_detailsOf] reads it back from the tree, so
/// assertions observe the exact state the UI submits.
Future<_Page> _pumpReadyDetails(
  WidgetTester tester,
  ProductModel product, {
  CatalogRepository? catalog,
}) async {
  SharedPreferences.setMockInitialValues({});
  await _setSurface(tester);
  final favorites = await _readyFavorites();
  final cart = CartCubit(
    cartRepository: LocalCartRepository(),
    catalogRepository: MockProductRepository(),
  );
  final branch = BranchCubit(repository: _FakeBranchRepository());
  addTearDown(favorites.close);
  addTearDown(cart.close);
  addTearDown(branch.close);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: branch),
          BlocProvider.value(value: favorites),
          BlocProvider.value(value: cart),
          RepositoryProvider<CatalogRepository>.value(
            value: catalog ?? MockProductRepository(),
          ),
        ],
        child: ProductDetailsPage(product: product),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return _Page(favorites: favorites, cart: cart, branch: branch);
}

/// The cubits a pumped details page is wired to.
class _Page {
  const _Page({
    required this.favorites,
    required this.cart,
    required this.branch,
  });

  final FavoritesCubit favorites;
  final CartCubit cart;
  final BranchCubit branch;
}

ProductDetailsCubit _detailsOf(WidgetTester tester) =>
    BlocProvider.of<ProductDetailsCubit>(
      tester.element(find.byType(ProductDetailsBody)),
    );

/// The offline catalogue answering the price the way a branch-pricing server
/// does: with its own pre-discount number, so a test can tell the two apart.
class _PricedCatalog extends MockProductRepository {
  /// How far the server's pre-discount price is put above the catalogue's, so
  /// an assertion on it cannot be satisfied by the catalogue value.
  static const double step = 10;

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) async {
    final product = await getById(productId, branchId: branchId);
    if (product == null) return null;
    return ResolvedPrice(
      unitPrice: product.price,
      regularPrice: product.oldPrice == null ? null : product.oldPrice! + step,
      currencyCode: 'SAR',
      isAvailable: true,
    );
  }
}

void main() {
  group('product details skeleton', () {
    testWidgets('mirrors the full-width image plus info column', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProductDetailsSkeleton())),
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
      final product = await _firstProduct();
      await _pumpReadyDetails(tester, product);

      // Header overlays the hero with two round controls: back + favourite.
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ),
        findsNWidgets(2),
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
      // The hero is a fixed logical height now, not a fraction of the screen:
      // a taller phone buys more content below it, not a taller image.
      expect(imageBox.height, AppDimensions.productHeroHeight);
    });

    testWidgets('a discounted product states the two prices and no percent', (
      tester,
    ) async {
      // The badge with the percentage used to hang off this page. What is left
      // is the pair of numbers: the price the customer pays and, struck
      // through, the price before the discount.
      final discounted = (await MockProductRepository().getProducts())
          .firstWhere((p) => p.hasDiscount);
      await _pumpReadyDetails(tester, discounted);

      final cubit = _detailsOf(tester);
      expect(cubit.hasDiscount, isTrue);
      expect(
        find.text(Formatters.amount(cubit.unitPrice)),
        findsWidgets,
        reason: 'the price the customer pays is on screen',
      );
      expect(
        find.text(Formatters.amount(cubit.regularPrice!)),
        findsOneWidget,
        reason: 'the price before the discount is on screen',
      );
      expect(
        find.textContaining('%'),
        findsNothing,
        reason: 'no percentage mark survives on the page',
      );
    });

    testWidgets(
      'the price the server reports replaces the catalogue discount',
      (tester) async {
        // A branch that charges differently is the case the card cannot know:
        // the server figure wins for both numbers, not only the live price.
        final discounted = (await MockProductRepository().getProducts())
            .firstWhere((p) => p.hasDiscount);
        await _pumpReadyDetails(tester, discounted, catalog: _PricedCatalog());

        final cubit = _detailsOf(tester);
        expect(cubit.regularPrice, discounted.oldPrice! + _PricedCatalog.step);
        expect(
          find.text(
            Formatters.amount(discounted.oldPrice! + _PricedCatalog.step),
          ),
          findsOneWidget,
          reason: 'the page prints what the server said, not the catalogue',
        );
      },
    );

    testWidgets('an undiscounted product gets no struck row', (tester) async {
      // A product with nothing to compare against must not grow a second
      // number just because the page can compare two prices.
      final plain = (await MockProductRepository().getProducts()).firstWhere(
        (p) => p.oldPrice == null,
      );
      await _pumpReadyDetails(tester, plain);

      final cubit = _detailsOf(tester);
      expect(cubit.regularPrice, isNull);
      expect(cubit.hasDiscount, isFalse);
      expect(
        find.text(Formatters.amount(cubit.unitPrice)),
        findsWidgets,
        reason: 'the one price the customer pays is still on screen',
      );
    });

    testWidgets('price and quantity live in the content', (tester) async {
      final product = await _firstProduct();
      await _pumpReadyDetails(tester, product);

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
        find.descendant(of: stepper, matching: find.byIcon(AppIcons.add)),
      );
      await tester.pump();
      expect(_detailsOf(tester).state.quantity, 2);
      expect(
        find.descendant(of: stepper, matching: find.text('2')),
        findsOneWidget,
      );

      // The minimum holds: decrementing at 1 stays at 1.
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(AppIcons.minus)),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(AppIcons.minus)),
      );
      await tester.pump();
      expect(_detailsOf(tester).state.quantity, 1);
    });

    testWidgets('bottom bar is Add to Cart only and submits quantity', (
      tester,
    ) async {
      final product = await _firstProduct();
      final page = await _pumpReadyDetails(tester, product);

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
        find.descendant(of: stepper, matching: find.byIcon(AppIcons.add)),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(AppIcons.add)),
      );
      await tester.pump();
      expect(_detailsOf(tester).state.quantity, 3);

      expect(page.cart.state.count, 0);
      await tester.tap(find.byType(AnimatedAddToCartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(page.cart.state.count, 3);
    });

    testWidgets('header fades the product name in once the hero is covered', (
      tester,
    ) async {
      final product = await _firstProduct();
      await _pumpReadyDetails(tester, product);

      final name = _detailsOf(tester).state.product!.name;

      double titleOpacity() {
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byType(AppBar),
                  matching: find.text(name),
                ),
                matching: find.byType(Opacity),
              )
              .first,
        );
        return opacity.opacity;
      }

      double headerBackgroundAlpha() {
        final box = tester.widget<DecoratedBox>(
          find.byKey(ProductDetailsPage.headerBackgroundKey),
        );
        final decoration = box.decoration as BoxDecoration;
        return decoration.color!.a;
      }

      // Hidden while the picture fills the header; nothing covers the photo.
      expect(titleOpacity(), 0);
      expect(headerBackgroundAlpha(), 0);

      // Scrolling the sheet up over the hero reveals the name on a solid bar.
      await tester.drag(find.byType(ProductDetailsBody), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(titleOpacity(), 1);
      expect(headerBackgroundAlpha(), 1);
    });

    testWidgets('header back and favourite keep the same edge gap', (
      tester,
    ) async {
      final product = await _firstProduct();
      await _pumpReadyDetails(tester, product);

      final appBar = tester.getRect(find.byType(AppBar));
      final buttons = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      );
      expect(buttons, findsNWidgets(2));

      final back = tester.getRect(buttons.first);
      final favourite = tester.getRect(buttons.last);

      // Both controls sit the same distance from their screen edge.
      expect(
        back.left - appBar.left,
        closeTo(appBar.right - favourite.right, 0.5),
      );
    });
  });

  group('goes well with', () {
    testWidgets('details shows same-category pairs, never itself', (
      tester,
    ) async {
      final product = await _firstProduct();
      await _pumpReadyDetails(tester, product);

      final pairs = _detailsOf(tester).state.pairs;
      expect(pairs, isNotEmpty);
      expect(pairs.length, lessThanOrEqualTo(5));
      expect(pairs.map((p) => p.id), isNot(contains(product.id)));
      expect(
        find.descendant(
          of: find.byType(ProductDetailsBody),
          matching: find.byType(HomeProductsCarousel),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bundle details derives pairs without extra requests', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _setSurface(tester);
      final bundles = await MockProductRepository().getBundles();
      final bundle = bundles.first;
      final favorites = await _readyFavorites();
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final branch = BranchCubit(repository: _FakeBranchRepository());
      addTearDown(favorites.close);
      addTearDown(cart.close);
      addTearDown(branch.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: branch),
              BlocProvider.value(value: favorites),
              BlocProvider.value(value: cart),
              RepositoryProvider<CatalogRepository>.value(
                value: MockProductRepository(),
              ),
            ],
            child: BundleDetailsPage(bundle: bundle),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final cubit = BlocProvider.of<BundleDetailsCubit>(
        tester.element(
          find.descendant(
            of: find.byType(BundleDetailsPage),
            matching: find.byType(Scaffold),
          ),
        ),
      );
      expect(cubit.state.products, isNotEmpty);
      final pairs = cubit.state.pairs;
      expect(pairs, isNotEmpty);
      expect(pairs.length, lessThanOrEqualTo(5));
      expect(
        pairs.map((p) => p.id).toSet(),
        isNot(contains(bundle.productIds.first)),
      );
      // Related products belong on product details, not bundle details.
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      expect(find.byType(HomeProductsCarousel), findsNothing);
    });
  });

  group('favorite buttons everywhere', () {
    testWidgets('details header heart fills red when saved', (tester) async {
      final product = await _firstProduct();
      final page = await _pumpReadyDetails(tester, product);

      // The header now also holds a back arrow, so target the heart icon
      // specifically instead of assuming the bar contains a single icon.
      Finder headerHeartIcon() => find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              (widget.icon == AppIcons.favourite ||
                  // Active state uses the Material filled heart.
                  widget.icon == Icons.favorite),
        ),
      );
      Icon headerHeart() => tester.widget<Icon>(headerHeartIcon());

      // Idle: outlined heart, existing grey styling.
      expect(headerHeart().icon, AppIcons.favourite);
      expect(headerHeart().color, AppColor.greyColor);

      await tester.tap(
        find.ancestor(of: headerHeartIcon(), matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();

      // Saved: the heart itself fills red, same persistence as cards.
      expect(headerHeart().icon, Icons.favorite);
      expect(headerHeart().color, AppColor.errorColor);
      expect(page.favorites.state.ids, contains(product.id));
    });
  });
}
