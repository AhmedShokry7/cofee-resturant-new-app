import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/addresses/presentation/manager/addresses/addresses_cubit.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/resilient_auth_repository.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/data/repositories/supabase_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/unavailable_catalog_repository.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/profile/data/repositories/profile_photo_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

/// Global dependency injection: repositories + app-wide blocs.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  /// The one place that decides which auth implementation runs.
  ///
  /// Supabase Auth is used exclusively. The repository is resilient: if the
  /// backend was not reachable when the app started, it reconnects on the
  /// next attempt instead of refusing every sign-in for the rest of the
  /// session. A mock that accepted any password would let a customer believe
  /// they were signed in while no account exists, so there is no mock.
  AuthRepository _buildAuthRepository() {
    return ResilientAuthRepository();
  }

  /// The one place that decides which catalogue source runs.
  ///
  /// The database is the only source. There is deliberately no mock fallback:
  /// fabricated products, prices and banners must never reach the customer.
  /// The offline fallback serves an empty catalogue instead, so the app
  /// renders its own "no results" state rather than a made-up menu.
  CatalogRepository _buildCatalogRepository() {
    if (SupabaseService.isReady) return SupabaseProductRepository();
    return const UnavailableCatalogRepository();
  }

  /// The server cart is authoritative. There is no local-only fallback: an
  /// order must always price and validate against the database.
  CartRepository _buildCartRepository() {
    if (SupabaseService.isReady) return SupabaseCartRepository();
    return LocalCartRepository();
  }

  OrdersRepository _buildOrdersRepository() {
    if (SupabaseService.isReady) return SupabaseOrdersRepository();
    return _UnavailableOrdersRepository();
  }

  @override
  Widget build(BuildContext context) {
    // One instance, exposed under both interfaces, so a category listing and a
    // product query can never come from two different snapshots.
    final catalog = _buildCatalogRepository();
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => _buildAuthRepository(),
        ),
        // Registered under all three names, pointing at one instance. A cubit
        // that asks for CatalogRepository must find it, and one that asks for
        // ProductRepository must get the same object.
        RepositoryProvider<CatalogRepository>.value(value: catalog),
        RepositoryProvider<ProductRepository>.value(value: catalog),
        RepositoryProvider<CategoryRepository>.value(value: catalog),
        RepositoryProvider<OrdersRepository>(
          create: (_) => _buildOrdersRepository(),
        ),
        RepositoryProvider<CartRepository>(
          create: (_) => _buildCartRepository(),
        ),
        RepositoryProvider<CouponRepository>(
          create: (_) => const CouponRepositoryImpl(),
        ),
        RepositoryProvider<AddressRepository>(
          create: (_) => SupabaseAddressRepository(),
        ),
        RepositoryProvider<PaymentMethodRepository>(
          create: (_) => SupabasePaymentMethodRepository(),
        ),
        // The charge repository. Not tied to one checkout — the same cubit can
        // be started for any order, so it is resolved from here rather than
        // created per payment page.
        RepositoryProvider<TapPaymentRepository>(
          create: (_) => SupabaseTapPaymentRepository(),
        ),
        RepositoryProvider<DeliveryZoneRepository>(
          create: (_) => SupabaseDeliveryZoneRepository(),
        ),
        RepositoryProvider<ContentRepository>(
          create: (_) => SupabaseContentRepository(),
        ),
        RepositoryProvider<DesignRepository>(
          create: (_) => SupabaseDesignRepository(),
        ),
        RepositoryProvider<PlaceSearchRepository>(
          create: (_) => NominatimPlaceSearchRepository(),
        ),
        RepositoryProvider<ProfilePhotoRepository>(
          create: (_) => SupabaseProfilePhotoRepository(),
        ),
        RepositoryProvider<SubscriptionRepository>(
          create: (_) => SubscriptionRepositoryImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            // يقرأ المنشور عند الإنشاء ويرسمه. الإقلاع طبّقه قبل أول إطار حين
            // وصلت القراءة، فهذه الثانية من الذاكرة لا من القاعدة.
            create: (context) =>
                DesignCubit(repository: context.read<DesignRepository>()),
          ),
          BlocProvider(
            create: (_) =>
                BranchCubit(repository: const BranchRepositoryImpl()),
          ),
          BlocProvider(
            // The cubit loads itself when it is created, so the cart is read
            // from the server exactly once per start.
            create: (context) => CartCubit(
              cartRepository: context.read<CartRepository>(),
              catalogRepository: context.read<CatalogRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => FavoritesCubit(
              repository: context.read<CatalogRepository>(),
              favorites: FavoritesRepositoryImpl(),
            ),
          ),
          BlocProvider(
            create: (context) => CheckoutCubit(
              coupons: context.read<CouponRepository>(),
              addresses: context.read<AddressRepository>(),
              paymentMethods: context.read<PaymentMethodRepository>(),
              deliveryZoneRepository: context.read<DeliveryZoneRepository>(),
              orders: context.read<OrdersRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                SavedCardsCubit(repository: SupabaseSavedCardsRepository())
                  ..load(),
          ),
          // The card payment cubit is app wide: the checkout charges an order
          // with it, and the subscription screens create their own instance for
          // a subscription. Without it here the checkout had no cubit to read
          // and every card payment failed before it started.
          BlocProvider(
            create: (context) => CardPaymentCubit(
              repository: context.read<TapPaymentRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => SearchCubit(
              catalogRepository: context.read<CatalogRepository>(),
              branchId: null,
            ),
          ),
          BlocProvider(
            create: (context) => NotificationsCubit(
              repository: const NotificationsRepositoryImpl(),
            )..load(),
          ),
          BlocProvider(
            create: (context) =>
                CategoriesCubit(repository: context.read<CatalogRepository>()),
          ),
          BlocProvider(
            create: (context) =>
                AddressesCubit(repository: context.read<AddressRepository>()),
          ),
          BlocProvider(
            create: (context) => ProfileCubit(
              repository: context.read<ProfilePhotoRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                HomeCubit(repository: context.read<CatalogRepository>()),
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
        child: _BranchSync(child: child),
      ),
    );
  }
}

/// Orders used when the backend could not be reached at startup.
///
/// Reads answer with an empty history, so the orders page renders its own
/// empty state instead of crashing. Writes refuse: an order must be priced
/// and validated by the server, and a locally "successful" order would be an
/// order nobody fulfils.
class _UnavailableOrdersRepository implements OrdersRepository {
  const _UnavailableOrdersRepository();

  static const String _message = 'Orders are not available without a backend.';

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async => throw StateError(_message);

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) async => throw StateError(_message);

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async =>
      throw StateError(_message);

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

/// Propagates the customer's explicit branch choice to every branch-aware
/// cubit.
///
/// Each cubit reloads only when the id actually changes, so opening the app
/// with a stored branch costs one coordinated refresh rather than unrelated
/// screens drifting across different branches.
class _BranchSync extends StatelessWidget {
  const _BranchSync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BranchCubit, BranchState>(
      listenWhen: (previous, current) =>
          previous.selected?.id != current.selected?.id,
      listener: (context, state) async {
        final branchId = state.selected?.id;
        context.read<CheckoutCubit>().setBranch(branchId);
        await Future.wait([
          context.read<CartCubit>().setBranch(branchId),
          context.read<FavoritesCubit>().setBranch(branchId),
          context.read<SearchCubit>().setBranch(branchId),
          context.read<CategoriesCubit>().setBranch(branchId),
          context.read<HomeCubit>().setBranch(branchId),
          context.read<LoyaltyCubit>().setBranch(branchId),
        ]);
      },
      // A coupon is approved for one exact cart; when the cart changes the
      // approval is dropped rather than shown against a cart it never priced.
      child: BlocListener<CartCubit, CartState>(
        listener: (context, cart) =>
            context.read<CheckoutCubit>().onCartChanged(cart.items),
        // Addresses are mirrored into two cubits: AddressesCubit owns them,
        // and CheckoutCubit keeps the copy the checkout screens render. Without
        // this the checkout kept the snapshot it took at construction, so an
        // address added — or made default — in Settings never reached it.
        child: BlocListener<AddressesCubit, AddressesState>(
          listenWhen: (previous, current) =>
              !listEquals(previous.addresses, current.addresses),
          listener: (context, addresses) => context
              .read<CheckoutCubit>()
              .onAddressesChanged(addresses.addresses),
          child: child,
        ),
      ),
    );
  }
}
