import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_cubit.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/widgets/coupon_card.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

/// The offers page is read on its own, from Settings, with no cart in front of
/// it: what it says about a code has to be true at the moment it is said.
class _FakeCoupons implements CouponRepository {
  _FakeCoupons({this.couponsToReturn = const []});

  List<CouponModel> couponsToReturn;
  Object? error;

  int calls = 0;

  @override
  Future<List<CouponModel>> activeCoupons() async {
    calls++;
    if (error != null) throw error!;
    return couponsToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The page reads the cart's applied code out of the checkout state, so a
/// checkout cubit has to exist in the tree the way it does in the running app.
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

CouponModel _coupon(String code, {int? perUserLimit, int usedCount = 0}) =>
    CouponModel(
      id: code,
      code: code,
      titleEn: 'Morning discount',
      discountValue: 15,
      perUserLimit: perUserLimit,
      usedCount: usedCount,
    );

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 900) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, CouponRepository repo) async {
  final checkout = CheckoutCubit(
    coupons: _FakeCoupons(),
    addresses: _FakeAddressRepository(),
    paymentMethods: _FakePaymentMethods(),
    deliveryZoneRepository: _FakeDeliveryZones(),
    orders: _FakeOrders(),
  );
  addTearDown(checkout.close);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [RepositoryProvider<CouponRepository>.value(value: repo)],
      child: MultiBlocProvider(
        providers: [BlocProvider.value(value: checkout)],
        child: const MaterialApp(home: CouponPage()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
    _ClipboardRecorder.install();
  });

  tearDown(() => _ClipboardRecorder.uninstall());

  testWidgets('a failed read is the customer\'s sentence, not the server\'s', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeCoupons()..error = StateError('permission denied');

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.couldNotLoadCoupons), findsOneWidget);
    expect(find.text(S.retry), findsOneWidget);
    expect(
      find.textContaining('permission denied'),
      findsNothing,
      reason: 'the backend message is never shown to the customer',
    );

    repository.error = null;
    await tester.tap(find.text(S.retry));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text(S.couldNotLoadCoupons), findsNothing);
  });

  testWidgets('a re-read that fails keeps the offers on screen', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeCoupons(couponsToReturn: [_coupon('MORNING')]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byType(CouponCard), findsOneWidget);

    repository.error = StateError('offline');
    await tester.pump();
    // The cubit is created inside the page, so the handle comes from a widget
    // under that provider, not from the page itself.
    final cubit = BlocProvider.of<CouponsCubit>(
      tester.element(find.text(S.coupon)),
    );
    await cubit.load();
    await tester.pumpAndSettle();

    expect(find.byType(CouponCard), findsOneWidget);
    expect(find.text(S.couponsOutdated), findsOneWidget);
    // The way back to a current list stays on the page it belongs to.
    expect(find.text(S.retry), findsOneWidget);
    expect(
      find.textContaining('offline'),
      findsNothing,
      reason: 'the backend message is never shown to the customer',
    );
  });

  testWidgets('no offers is a stated state, not a failure', (tester) async {
    _setSurface(tester);
    final repository = _FakeCoupons();

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.noCoupons), findsOneWidget);
    expect(find.text(S.noCouponsHint), findsOneWidget);
    expect(
      find.text(S.couldNotLoadCoupons),
      findsNothing,
      reason: 'an empty catalogue is an answer, not an error',
    );
  });

  testWidgets('the code is copied and the tap says what it did', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeCoupons(couponsToReturn: [_coupon('MORNING')]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The announcement names both the action and what it puts on the device.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == '${S.copyCode}: MORNING',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(S.copyCode));
    await tester.pumpAndSettle();

    expect(_ClipboardRecorder.lastCopied, 'MORNING');
    expect(find.text(S.codeCopied('MORNING')), findsOneWidget);
  });

  testWidgets('a device that refuses the clipboard says so', (tester) async {
    _setSurface(tester);
    _ClipboardRecorder.refuseNext = true;
    final repository = _FakeCoupons(couponsToReturn: [_coupon('MORNING')]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.copyCode));
    await tester.pumpAndSettle();

    expect(_ClipboardRecorder.lastCopied, isNull);
    expect(find.text(S.couldNotCopyCode), findsOneWidget);
    expect(
      find.text(S.codeCopied('MORNING')),
      findsNothing,
      reason: 'the code never left the page, so the promise is not made',
    );
  });

  testWidgets('a spent coupon is stated once and copies nothing', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeCoupons(
      couponsToReturn: [_coupon('MORNING', perUserLimit: 1, usedCount: 1)],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The strip under the card says it, and the card does not say it twice.
    expect(find.text(S.couponNoUsesLeft), findsOneWidget);
    expect(find.text(S.copyCode), findsNothing);

    await tester.tap(find.text(S.couponNoUsesLeft));
    await tester.pumpAndSettle();

    expect(
      _ClipboardRecorder.lastCopied,
      isNull,
      reason: 'a code the customer cannot use is not offered for copying',
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a coupon with uses left is counted, not greyed', (tester) async {
    _setSurface(tester);
    final repository = _FakeCoupons(
      couponsToReturn: [_coupon('MORNING', perUserLimit: 3, usedCount: 1)],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.couponUsesLeft(2)), findsOneWidget);
    expect(find.text(S.couponNoUsesLeft), findsNothing);

    await tester.tap(find.text(S.copyCode));
    await tester.pumpAndSettle();

    expect(_ClipboardRecorder.lastCopied, 'MORNING');
  });
}

/// The clipboard is a platform channel: the copy is only proven by what the
/// device was asked to hold. `SystemChannels.platform` is a JSON channel, so
/// that exact channel object - not a bare name - has to be mocked.
class _ClipboardRecorder {
  static String? lastCopied;
  static bool refuseNext = false;

  static void install() {
    lastCopied = null;
    refuseNext = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method != 'Clipboard.setData') return null;
          if (refuseNext) {
            refuseNext = false;
            throw PlatformException(code: 'denied');
          }
          final arguments = call.arguments as Map<Object?, Object?>;
          lastCopied = arguments['text'] as String?;
          return null;
        });
  }

  static void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}
