import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
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
import 'package:new_coffee/features/profile/presentation/views/profile_page.dart';

// ---------------------------------------------------------------- fakes ----

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({List<NotificationModel>? rows})
    : rows = rows ?? const [];

  List<NotificationModel> rows;
  Object? failNext;
  Completer<void>? gate;

  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async {
    // What the server had at request time, captured before any await, the way a
    // real answer belongs to the request and not to the moment it lands.
    final snapshot = List<NotificationModel>.of(rows);
    final held = gate;
    if (held != null) {
      gate = null;
      await held.future;
    }
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return snapshot;
  }

  @override
  Future<int> markRead(List<String> ids) async => ids.length;
}

class _ScriptedLoyaltyRepository implements LoyaltyRepository {
  _ScriptedLoyaltyRepository();

  int balance = 99;
  Object? failNext;

  @override
  Future<LoyaltyCatalog> loadCatalog() async => const LoyaltyCatalog();

  @override
  Future<LoyaltyWallet?> loadWallet() async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return LoyaltyWallet(balance: balance, tier: 'gold');
  }

  @override
  Future<int> redeemReward({
    required String productId,
    required String branchId,
  }) => Future.value(0);
}

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;
  Object? signOutError;
  Future<void>? signOutGate;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final held = signOutGate;
    if (held != null) await held;
    final error = signOutError;
    if (error != null) throw error;
  }

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithFacebook() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithApple() => throw UnimplementedError();

  @override
  Future<void> sendPhoneCode({required String phone}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();
}

class _FailingOnceFavorites implements FavoritesRepository {
  _FailingOnceFavorites(this._inner);

  final FavoritesRepository _inner;

  Object? failNext;
  int migrateCalls = 0;

  @override
  Future<void> migrateGuestIds() {
    migrateCalls++;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Future<void>.error(failure, StackTrace.current);
    }
    return _inner.migrateGuestIds();
  }

  @override
  Future<Set<String>> loadLocalIds() => _inner.loadLocalIds();

  @override
  Future<Set<String>> synchronizedIds(
    Set<String> localIds, {
    required Set<String> validProductIds,
  }) => _inner.synchronizedIds(
    localIds,
    validProductIds: validProductIds,
  );

  @override
  Future<void> addFavorite(String productId) => _inner.addFavorite(productId);

  @override
  Future<void> removeFavorite(String productId) =>
      _inner.removeFavorite(productId);
}

NotificationModel _row(String id) => NotificationModel(
  id: id,
  titleAr: 'عنوان $id',
  titleEn: 'Title $id',
  bodyAr: 'نص $id',
  bodyEn: 'Body $id',
  type: 'order_status',
  createdAt: DateTime.now(),
);

Future<void> _settle([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('cart isolation', () {
    test('an empty cart for the new identity never shows the old one', () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_user-a': jsonEncode([
          {'productId': '1', 'quantity': 2},
        ]),
        // user-b simply has no cart.
      });
      String? current = 'user-a';
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => current,
      );
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.items.single.product.id, '1');

      // The account switches; the previous customer's lines must not survive.
      current = 'user-b';
      expect(cubit.applyIdentityTransition('user-b'), isTrue);
      expect(cubit.state.items, isEmpty);

      await cubit.load();
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.total, 0);
    });

    test('the old identity storage slot is not deleted by the clear', () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_user-a': jsonEncode([
          {'productId': '1', 'quantity': 2},
        ]),
      });
      String? current = 'user-a';
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => current,
      );
      addTearDown(cubit.close);
      await _settle();

      current = null;
      cubit.applyIdentityTransition(null);
      expect(cubit.state.items, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('cart_v1_user-a'),
        jsonEncode([
          {'productId': '1', 'quantity': 2},
        ]),
        reason: 'signing out must not destroy the account cart on disk',
      );

      // Signing back in restores that customer's own cart.
      current = 'user-a';
      await cubit.load();
      expect(cubit.state.items.single.product.id, '1');
    });

    test('an ordinary reload does not clear the cart', () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_user-a': jsonEncode([
          {'productId': '1', 'quantity': 1},
        ]),
      });
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => 'user-a',
      );
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.items, isNotEmpty);

      expect(cubit.applyIdentityTransition('user-a'), isFalse);
      await cubit.load();
      expect(cubit.state.items.single.product.id, '1');
    });
  });

  group('notifications isolation', () {
    test('a failed read after a switch cannot show the old rows', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('a1')]);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.notifications.single.id, 'a1');

      expect(cubit.applyIdentityTransition('user-b'), isTrue);
      expect(
        cubit.state.notifications,
        isEmpty,
        reason: 'the previous customer rows leave the moment the account does',
      );

      repository.failNext = StateError('network down');
      await cubit.load();

      expect(cubit.state.notifications, isEmpty);
      expect(cubit.state.error, isNotNull);
    });

    test('an ordinary refresh that fails keeps the same customer rows', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('a1')]);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);
      await _settle();

      repository.failNext = StateError('network down');
      await cubit.refresh();

      expect(
        cubit.state.notifications.single.id,
        'a1',
        reason: 'a refresh failure for the same customer must not blank the list',
      );
      expect(cubit.state.error, isNotNull);
    });

    test('a read parked under the old identity cannot land afterwards', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('a1')]);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.notifications.single.id, 'a1');

      // The next read is held open under customer A's session...
      final gate = Completer<void>();
      repository.gate = gate;
      final stale = cubit.refresh();

      // ...while customer B takes over and gets a read of their own.
      cubit.applyIdentityTransition('user-b');
      repository.rows = [_row('b1')];
      final after = <List<String>>[];
      final seen = cubit.stream.listen(
        (state) => after.add(state.notifications.map((n) => n.id).toList()),
      );
      final fresh = cubit.refresh();

      // A's answer finally arrives, late.
      gate.complete();
      await stale;
      await fresh;
      await seen.cancel();

      expect(
        after.any((ids) => ids.contains('a1')),
        isFalse,
        reason: 'a stale in-flight read must never restore the old customer',
      );
      expect(cubit.state.notifications.single.id, 'b1');
    });
  });

  group('loyalty isolation', () {
    test('a failed read after a switch cannot expose the old balance', () async {
      final repository = _ScriptedLoyaltyRepository();
      final cubit = LoyaltyCubit(repository: repository);
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.state.balance, 99);

      expect(cubit.applyIdentityTransition('user-b'), isTrue);
      expect(cubit.state.balance, 0);
      expect(cubit.state.transactions, isEmpty);

      repository.failNext = StateError('network down');
      await cubit.load();

      expect(cubit.state.balance, 0);
      expect(cubit.state.transactions, isEmpty);
      expect(cubit.state.tier, 'guest');
    });

    test('a failed ordinary refresh keeps the same customer balance', () async {
      final repository = _ScriptedLoyaltyRepository();
      final cubit = LoyaltyCubit(repository: repository);
      addTearDown(cubit.close);
      await _settle();

      repository.failNext = StateError('network down');
      await cubit.load();

      expect(cubit.state.balance, 99);
      expect(cubit.state.error, isNotNull);
    });
  });

  group('favorites isolation', () {
    test('new ids cannot resolve against the previous account rows', () async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_user-a': jsonEncode(['1']),
        'favorites_v1_user-b': jsonEncode(['2']),
      });
      String? current = 'user-a';
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(userIdProvider: () => current),
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(cubit.state.favoriteProducts.single.name, 'Espresso');

      current = 'user-b';
      expect(cubit.applyIdentityTransition('user-b'), isTrue);
      expect(cubit.state.ids, isEmpty);
      expect(cubit.state.products, isEmpty);

      await cubit.load();
      expect(cubit.state.ids, {'2'});
      expect(
        cubit.state.favoriteProducts.single.name,
        'Cappuccino',
        reason: 'user-b resolves to their own row, not user-a product 1',
      );
    });

    test('guest hearts are still adopted after the transition', () async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_guest': jsonEncode(['2']),
      });
      final repository = FavoritesRepositoryImpl();
      await repository.addFavorite('2');

      String? current;
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(userIdProvider: () => current),
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(cubit.state.ids, {'2'});

      // Signing in must move the guest hearts into the account, not lose them.
      current = 'user-a';
      cubit.applyIdentityTransition('user-a');
      await cubit.load();
      expect(cubit.state.ids, contains('2'));
    });

    test('a failed migration does not block a retry or lose guest hearts', () async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_guest': jsonEncode(['2']),
      });
      final inner = FavoritesRepositoryImpl(userIdProvider: () => 'user-a');
      await inner.addFavorite('2');

      final favorites = _FailingOnceFavorites(inner)
        ..failNext = StateError('migration failed');
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: favorites,
      );
      addTearDown(cubit.close);

      // The constructor load hits the failure. It must be reported, not thrown
      // into an unhandled async error, and it must settle.
      await _settle();
      expect(
        cubit.state.isLoading,
        isFalse,
        reason: 'a failed migration must not wedge the cubit in loading',
      );

      // The retry runs a fresh migration, because the in-flight reference was
      // released on failure.
      final settled = cubit.stream.firstWhere((state) => !state.isLoading);
      await cubit.load();
      await settled;

      expect(favorites.migrateCalls, 2);
      expect(
        cubit.state.ids,
        contains('2'),
        reason: 'the guest heart survives a failed migration and a retry',
      );
    });
  });

  group('logout', () {
    const authScreenKey = ValueKey('auth_screen');

    Future<void> pumpSettings(WidgetTester tester, AuthRepository auth) async {
      // Tall enough for the full settings list including the Language and
      // My Addresses entries added below the privacy policy row.
      tester.view.physicalSize = const Size(360, 1150) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
            routes: {
              'authRoute': (_) =>
                  const Scaffold(key: authScreenKey, body: Text('AUTH')),
            },
            home: RepositoryProvider<AuthRepository>.value(
              value: auth,
              child: BlocProvider(
                create: (_) => ProfileCubit(),
                child: const SettingsPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> openAndConfirm(WidgetTester tester) async {
      await tester.tap(find.text(S.logOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.confirmLogout));
      await tester.pump();
    }

    testWidgets('signs out once through the repository, then navigates', (
      tester,
    ) async {
      final auth = _FakeAuthRepository();
      await pumpSettings(tester, auth);

      final gate = Completer<void>();
      auth.signOutGate = gate.future;

      await tester.tap(find.text(S.logOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.confirmLogout));
      await tester.pump();

      // A second tap while the first sign-out is in flight must be a no-op.
      await tester.tap(find.text(S.confirmLogout), warnIfMissed: false);
      await tester.pump();
      expect(auth.signOutCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(find.byKey(authScreenKey), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstant.routesKey), AppConstant.authRoute);
    });

    testWidgets('a failed sign-out neither navigates nor claims success', (
      tester,
    ) async {
      final auth = _FakeAuthRepository()
        ..signOutError = StateError('sign out failed');
      await pumpSettings(tester, auth);

      await openAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(find.byKey(authScreenKey), findsNothing);
      expect(
        find.byType(SettingsPage),
        findsOneWidget,
        reason: 'the customer must still be on the settings screen',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppConstant.routesKey),
        isNull,
        reason: 'the stored route must not be cleared when sign-out failed',
      );

      // A later attempt is still possible.
      auth.signOutError = null;
      await openAndConfirm(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(authScreenKey), findsOneWidget);
      expect(auth.signOutCalls, 2);
    });

    testWidgets('shows the localized failure message, not a hard-coded one', (
      tester,
    ) async {
      final auth = _FakeAuthRepository()
        ..signOutError = StateError('sign out failed');
      await pumpSettings(tester, auth);

      await openAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(find.text(S.logoutFailed), findsOneWidget);
      expect(find.text(S.logOut), findsWidgets);
    });
  });

  group('sign-out refuses to fake a success', () {
    test(
      'an unconfigured backend throws instead of returning quietly',
      () async {
        SupabaseService.debugReset();
        addTearDown(SupabaseService.debugReset);
        expect(SupabaseService.isReady, isFalse);

        final repository = SupabaseAuthRepository();

        await expectLater(
          repository.signOut(),
          throwsA(isA<AuthException>()),
        );
      },
    );
  });
}