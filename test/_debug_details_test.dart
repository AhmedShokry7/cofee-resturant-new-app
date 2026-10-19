import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_body.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_bottom_bar.dart';

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<Branch>> activeBranches() async => const [];
}

Future<void> main() async {
  testWidgets('debug details', (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    final products = await MockProductRepository().getProducts();
    final product = products.first;
    final fav = FavoritesCubit(repository: MockProductRepository(), favorites: FavoritesRepositoryImpl());
    await fav.stream.firstWhere((s) => !s.isLoading);
    final cart = CartCubit(cartRepository: LocalCartRepository(), catalogRepository: MockProductRepository());
    final branch = BranchCubit(repository: _FakeBranchRepository() as dynamic);
    await tester.pumpWidget(ScreenUtilInit(designSize: const Size(360,690), builder: (context, _) => MaterialApp(home: MultiBlocProvider(providers: [BlocProvider.value(value: branch), BlocProvider.value(value: fav), BlocProvider.value(value: cart), RepositoryProvider<CatalogRepository>.value(value: MockProductRepository())], child: ProductDetailsPage(product: product)))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    print('SKELETON: ${find.byType(ProductDetailsSkeleton).evaluate().length}');
    print('BODY: ${find.byType(ProductDetailsBody).evaluate().length}');
    print('BOTTOM: ${find.byType(ProductDetailsBottomBar).evaluate().length}');
  });
}
