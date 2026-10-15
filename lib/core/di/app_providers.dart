import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

/// Global dependency injection: repositories + app-wide blocs.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  /// The one place that decides which auth implementation runs.
  ///
  /// Both implementations satisfy the same [AuthRepository] contract, so every
  /// screen and cubit is unaware of the swap. Supabase is used when the build
  /// supplied credentials and the client initialised; otherwise the local mock
  /// keeps the app runnable offline.
  AuthRepository _buildAuthRepository() {
    if (SupabaseService.isReady) return SupabaseAuthRepository();
    return const AuthRepositoryImpl();
  }

  /// The one place that decides which catalogue source runs.
  ///
  /// Same contract, same fallback. SupabaseProductRepository reads the
  /// `public` routing views, which run with the caller's role so the catalogue
  /// RLS still decides the rows.
  CatalogRepository _buildCatalogRepository() {
    if (SupabaseService.isReady) return SupabaseProductRepository();
    return const MockProductRepository();
  }

  /// Orders and cancellation go through the order backend when available.
  ///
  /// Offline callers get an explicitly empty history rather than the five
  /// invented orders the old mock supplied.
  OrdersRepository _buildOrdersRepository() {
    if (SupabaseService.isReady) return SupabaseOrdersRepository();
    return const LocalOrdersRepository();
  }

  @override
  Widget build(BuildContext context) {
    // One instance, exposed under both interfaces, so a category listing and a
    // product query can never come from two different snapshots.
    final catalog = _buildCatalogRepository();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => _buildAuthRepository()),
        // Registered under all three names, pointing at one instance. A cubit
        // that asks for CatalogRepository must find it, and one that asks for
        // ProductRepository must get the same object.
        RepositoryProvider<CatalogRepository>.value(value: catalog),
        RepositoryProvider<ProductRepository>.value(value: catalog),
        RepositoryProvider<CategoryRepository>.value(value: catalog),
        RepositoryProvider<OrdersRepository>(
          create: (_) => _buildOrdersRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => CartCubit(
              repository: context.read<CatalogRepository>(),
            )..load(),
          ),
          BlocProvider(
            create: (context) => FavoritesCubit(
              repository: context.read<CatalogRepository>(),
              favorites: FavoritesRepositoryImpl(),
            )..load(),
          ),
          BlocProvider(create: (context) => CheckoutCubit()),
          BlocProvider(create: (context) => SavedCardsCubit()..load()),
          BlocProvider(
            create: (context) => SearchCubit(
              catalogRepository: context.read<CatalogRepository>(),
              branchId: null,
            ),
          ),
          BlocProvider(create: (context) => NotificationsCubit()..load()),
          BlocProvider(
            create: (context) =>
                CategoriesCubit(repository: context.read<CatalogRepository>()),
          ),
          BlocProvider(create: (context) => ProfileCubit()),
          BlocProvider(
            create: (context) => HomeCubit(
              repository: context.read<CatalogRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => LoyaltyCubit(
              repository: LoyaltyRepositoryImpl(
                catalog: context.read<CatalogRepository>(),
              ),
            )..load(),
          ),
          BlocProvider(
            create: (context) =>
                WeatherCubit(const WeatherRepositoryImpl())..load(),
          ),
        ],
        child: child,
      ),
    );
  }
}
