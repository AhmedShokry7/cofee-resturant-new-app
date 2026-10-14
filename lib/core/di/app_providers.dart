import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

/// Global dependency injection: repositories + app-wide blocs.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AuthRepository>(
      create: (context) => const AuthRepositoryImpl(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => CartCubit()..load()),
          BlocProvider(create: (context) => FavoritesCubit()..load()),
          BlocProvider(create: (context) => CheckoutCubit()),
          BlocProvider(create: (context) => SavedCardsCubit()..load()),
          BlocProvider(create: (context) => SearchCubit()),
          BlocProvider(create: (context) => NotificationsCubit()..load()),
          BlocProvider(create: (context) => CategoriesCubit()),
          BlocProvider(create: (context) => ProfileCubit()),
          BlocProvider(create: (context) => LoyaltyCubit()..load()),
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
