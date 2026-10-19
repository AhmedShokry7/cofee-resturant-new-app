import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';

import 'support/in_memory_profile_photo_repository.dart';

/// Minimal stand-in for what a signed-out customer sees.
class _SignedOutNotifications implements NotificationsRepository {
  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async =>
      throw const NotificationSignInRequiredException();

  @override
  Future<int> markRead(List<String> ids) async => 0;
}

/// The auth stream is a replaying stream, so a cubit registered during startup
/// is handed `initialSession` immediately. Treating that as a reason to reload
/// is what multiplied every load at boot.
class _NeverFiresLoyaltyRepository implements LoyaltyRepository {
  @override
  Future<LoyaltyCatalog> loadCatalog() async => const LoyaltyCatalog();

  @override
  Future<LoyaltyWallet?> loadWallet() async => null;

  @override
  Future<int> redeemReward({
    required String productId,
    required String branchId,
  }) => Future.value(0);
}

/// Auth-event policy tests.
///
/// **Coverage boundary â€” read before trusting a green run here.** These tests
/// call each cubit's `shouldReloadOnAuthEvent` directly. They therefore prove
/// the policy table, and nothing more. They do NOT prove that
/// `onAuthStateChange` is subscribed, that GoTrue replays `initialSession` to a
/// late subscriber, or that a policy hit actually results in a `load()`. That
/// wiring needs `SupabaseService.isReady == true` and has no coverage; it is
/// listed as an open gap in the Phase A review.
AuthState _event(AuthChangeEvent type) => AuthState(type, null);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('auth events that must not reload', () {
    const ignored = [
      AuthChangeEvent.initialSession,
      AuthChangeEvent.tokenRefreshed,
      AuthChangeEvent.userUpdated,
      AuthChangeEvent.mfaChallengeVerified,
    ];

    test('a token rotation alone is not a reason to reload', () async {
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final favorites = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(),
      );
      final notifications = NotificationsCubit(
        repository: _SignedOutNotifications(),
      );
      final loyalty = LoyaltyCubit(repository: _NeverFiresLoyaltyRepository());
      final profile = ProfileCubit(
        repository: InMemoryProfilePhotoRepository(),
      );
      addTearDown(cart.close);
      addTearDown(favorites.close);
      addTearDown(notifications.close);
      addTearDown(loyalty.close);
      addTearDown(profile.close);

      final cubits = <bool Function(AuthState)>[
        cart.shouldReloadOnAuthEvent,
        favorites.shouldReloadOnAuthEvent,
        notifications.shouldReloadOnAuthEvent,
        loyalty.shouldReloadOnAuthEvent,
        profile.shouldReloadOnAuthEvent,
      ];

      for (final event in ignored) {
        for (final shouldReload in cubits) {
          expect(
            shouldReload(_event(event)),
            isFalse,
            reason: '$event must not trigger a reload',
          );
        }
      }
    });
  });

  group('auth events that must reload', () {
    test('a session change reloads every account-scoped cubit', () async {
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final favorites = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(),
      );
      final notifications = NotificationsCubit(
        repository: _SignedOutNotifications(),
      );
      final loyalty = LoyaltyCubit(repository: _NeverFiresLoyaltyRepository());
      final profile = ProfileCubit(
        repository: InMemoryProfilePhotoRepository(),
      );
      addTearDown(cart.close);
      addTearDown(favorites.close);
      addTearDown(notifications.close);
      addTearDown(loyalty.close);
      addTearDown(profile.close);

      final cubits = <bool Function(AuthState)>[
        cart.shouldReloadOnAuthEvent,
        favorites.shouldReloadOnAuthEvent,
        notifications.shouldReloadOnAuthEvent,
        loyalty.shouldReloadOnAuthEvent,
        profile.shouldReloadOnAuthEvent,
      ];

      for (final event in const [
        AuthChangeEvent.signedIn,
        AuthChangeEvent.passwordRecovery,
        AuthChangeEvent.signedOut,
      ]) {
        for (final shouldReload in cubits) {
          expect(
            shouldReload(_event(event)),
            isTrue,
            reason: '$event must reload, the account behind the data changed',
          );
        }
      }
    });
  });

  group('password recovery is a session change, not a token refresh', () {
    // GoTrue emits `passwordRecovery` *instead of* `signedIn` when a recovery
    // link establishes the session, and this app supports that flow
    // (`SupabaseAuthRepository._requireRecoverySession`). Treating it as an
    // ignorable event left the previous customer's data on screen.
    test('every cubit reloads on it', () async {
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      final favorites = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(),
      );
      final notifications = NotificationsCubit(
        repository: _SignedOutNotifications(),
      );
      final loyalty = LoyaltyCubit(repository: _NeverFiresLoyaltyRepository());
      final profile = ProfileCubit(
        repository: InMemoryProfilePhotoRepository(),
      );
      addTearDown(cart.close);
      addTearDown(favorites.close);
      addTearDown(notifications.close);
      addTearDown(loyalty.close);
      addTearDown(profile.close);

      final recovery = _event(AuthChangeEvent.passwordRecovery);
      expect(cart.shouldReloadOnAuthEvent(recovery), isTrue);
      expect(favorites.shouldReloadOnAuthEvent(recovery), isTrue);
      expect(notifications.shouldReloadOnAuthEvent(recovery), isTrue);
expect(loyalty.shouldReloadOnAuthEvent(recovery), isTrue);
      expect(profile.shouldReloadOnAuthEvent(recovery), isTrue);
    });

    test('it stays distinct from the events that must not reload', () async {
      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      addTearDown(cart.close);

      expect(
        cart.shouldReloadOnAuthEvent(_event(AuthChangeEvent.tokenRefreshed)),
        isFalse,
      );
      expect(
        cart.shouldReloadOnAuthEvent(_event(AuthChangeEvent.initialSession)),
        isFalse,
      );
      expect(
        cart.shouldReloadOnAuthEvent(_event(AuthChangeEvent.userUpdated)),
        isFalse,
      );
    });
  });

  group('startup still reads the signed-in customer', () {
    test('initialSession is not a reload trigger (policy level)', () async {
      // The constructor is the one startup read. A replayed initialSession is
      // ignored, so a replay cannot add a second one on top of it.
      //
      // This asserts the policy function, not the subscription. Nothing here
      // replays an event, and the real `onAuthStateChange` wiring is not
      // covered by any test because it needs `SupabaseService.isReady == true`.
      final catalog = MockProductRepository();
      final before = await catalog.getProducts();
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: catalog,
        userIdProvider: () => 'user-a',
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        cubit.shouldReloadOnAuthEvent(_event(AuthChangeEvent.initialSession)),
        isFalse,
      );
      expect(before, isNotEmpty);
    });

    test('signed-out clears the previous customer notifications', () async {
      final cubit = NotificationsCubit(
        repository: _SignedOutNotifications(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.signedOut, isTrue);
      expect(cubit.state.notifications, isEmpty);
      expect(cubit.unreadCount, 0);
    });

    test('the cart never exposes another account slot', () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_user-a': jsonEncode([
          {'productId': '1', 'quantity': 4},
        ]),
        'cart_v1_user-b': jsonEncode([
          {'productId': '2', 'quantity': 1},
        ]),
      });

      String? currentUser = 'user-a';
      final a = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => currentUser,
      );
      addTearDown(a.close);
      await a.load();
      expect(a.state.items.single.product.id, '1');

      currentUser = 'user-b';
      final b = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => currentUser,
      );
      addTearDown(b.close);
      await b.load();
      expect(b.state.items.single.product.id, '2');
    });
  });
}