// The language switch has to re-render the screen the customer is standing on.
//
// `S` reads the current [AppLocale] at build time, so a screen only changes
// language if its `build` actually runs again. Flutter skips the update of a
// widget whose new instance is identical to the old one, which is exactly what
// `const SomePage()` hands the tree — so a const page keeps the strings it was
// first built with, and the customer has to restart the app to read the screen
// they asked for. These tests drive the real route table, so the guard covers
// the pages the app actually shows.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/locale/locale_rebuild.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/profile_page.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

import 'support/in_memory_profile_photo_repository.dart';

class _FakeCoupons implements CouponRepository {
  _FakeCoupons(this.coupons);

  final List<CouponModel> coupons;

  @override
  Future<List<CouponModel>> activeCoupons() async => coupons;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAddressRepository implements AddressRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePaymentMethods implements PaymentMethodRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeDeliveryZones implements DeliveryZoneRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeOrders implements OrdersRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get lastSignUpNeedsEmailConfirmation => false;

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The root of `app.dart`, production widget included: [LocaleRebuild] walks
/// the tree on a language change and `MaterialApp` carries the new locale.
Widget _appLikeRoot({required WidgetBuilder pageBuilder}) {
  return LocaleRebuild(
    child: AnimatedBuilder(
      animation: AppLocale.instance,
      builder: (context, _) => MaterialApp(
        locale: AppLocale.instance.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        builder: (context, inner) => Directionality(
          textDirection: AppLocale.instance.textDirection,
          child: inner ?? const SizedBox.shrink(),
        ),
        home: Builder(builder: pageBuilder),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a language switch re-renders the page already on screen', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    const routeName = CouponPage.routeName;

    final checkout = CheckoutCubit(
      coupons: _FakeCoupons(const []),
      addresses: _FakeAddressRepository(),
      paymentMethods: _FakePaymentMethods(),
      deliveryZoneRepository: _FakeDeliveryZones(),
      orders: _FakeOrders(),
    );
    addTearDown(checkout.close);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CouponRepository>.value(
            value: _FakeCoupons(const [_morning]),
          ),
        ],
        child: MultiBlocProvider(
          providers: [BlocProvider.value(value: checkout)],
          // The page comes out of the table the app navigates with, so this
          // fails when a route builder is frozen, not just when a test widget is.
          child: _appLikeRoot(
            pageBuilder: (context) => AppRoutes.routes[routeName]!(context),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final arabicTitle = S.coupon;
    expect(find.text(arabicTitle), findsOneWidget);

    await AppLocale.instance.setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();

    expect(
      find.text(S.coupon),
      findsOneWidget,
      reason: 'the page title has to follow the language the customer chose',
    );
    expect(
      find.text(arabicTitle),
      findsNothing,
      reason: 'nothing on the page may stay in the language they left',
    );
  });

  testWidgets('the switch keeps the place the customer stopped typing', (
    tester,
  ) async {
    // A const subtree is the one that does not re-read `S`, so it is the subtree
    // this fix is for — and the state inside it still has to survive, which a
    // remount (a key on the route, or a restart) would throw away.
    AppLocale.instance.debugSet(AppLanguage.arabic);

    await tester.pumpWidget(
      _appLikeRoot(pageBuilder: (_) => const _FrozenLabelField()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'less sugar');
    expect(find.text(S.coupon), findsOneWidget);

    await AppLocale.instance.setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();

    final field = tester.state<_FrozenLabelFieldState>(
      find.byType(_FrozenLabelField),
    );
    expect(field.buildCount, greaterThan(1));
    expect(find.text(S.coupon), findsOneWidget);
    expect(
      find.textContaining('less sugar'),
      findsOneWidget,
      reason: 're-localizing is not a reason to lose a typed note',
    );
  });

  testWidgets('the Settings tab relabels every entry on the tap that chose it', (
    tester,
  ) async {
    // The tab the language is changed from. It has no route of its own and is
    // handed to the shell as a `const` instance, so it is the screen that used
    // to need a hot restart before any of its labels moved.
    AppLocale.instance.debugSet(AppLanguage.arabic);
    tester.view.physicalSize = const Size(360, 1200) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ProfileCubit(repository: InMemoryProfilePhotoRepository());
    addTearDown(profile.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: profile)],
        child: RepositoryProvider<AuthRepository>(
          create: (_) => _FakeAuthRepository(),
          child: _appLikeRoot(pageBuilder: (_) => const SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final arabicAddresses = S.myAddresses;
    final arabicLanguage = S.language;
    expect(find.text(arabicAddresses), findsOneWidget);
    expect(find.text(arabicLanguage), findsOneWidget);

    await AppLocale.instance.setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();

    expect(
      find.text(S.myAddresses),
      findsOneWidget,
      reason: 'the entries below the fold are part of the same tree',
    );
    expect(find.text(S.language), findsOneWidget);
    expect(
      find.text(arabicAddresses),
      findsNothing,
      reason: 'a tab has no reason to keep the language the customer left',
    );
    expect(find.text(arabicLanguage), findsNothing);
  });

  testWidgets('the app root really installs the walk', (tester) async {
    // The mechanism lives in `app.dart`, not in this test's harness, so a
    // refactor that drops it has to fail here rather than in the Settings tab.
    final root = File('lib/app.dart').readAsStringSync();
    expect(
      root,
      contains('LocaleRebuild('),
      reason:
          'without the walk, every `const` route page keeps the language it '
          'was first built in',
    );
  });
}

/// A page whose instance is canonicalized by `const`, holding the text the
/// customer was busy typing.
class _FrozenLabelField extends StatefulWidget {
  const _FrozenLabelField();

  @override
  State<_FrozenLabelField> createState() => _FrozenLabelFieldState();
}

class _FrozenLabelFieldState extends State<_FrozenLabelField> {
  int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return Scaffold(
      appBar: AppBar(title: Text(S.coupon)),
      body: const Padding(padding: EdgeInsets.all(16), child: TextField()),
    );
  }
}

/// The offers row the page is built around, in both stored languages, so the
/// test can tell a re-read apart from a leftover.
const _morning = CouponModel(
  id: 'MORNING',
  code: 'MORNING',
  titleEn: 'Morning discount',
  titleAr: 'خصم الصباح',
  discountValue: 15,
);
