import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_cubit.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_state.dart';

/// The list the page shows: what the server answers, and nothing else.
class _FakeCoupons implements CouponRepository {
  _FakeCoupons({List<CouponModel> coupons = const [], this.error})
    : couponsToReturn = coupons;

  List<CouponModel> couponsToReturn;
  Object? error;

  int calls = 0;

  void succeed({List<CouponModel> coupons = const []}) {
    error = null;
    couponsToReturn = coupons;
  }

  @override
  Future<List<CouponModel>> activeCoupons() async {
    calls++;
    if (error != null) throw error!;
    return couponsToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

CouponModel coupon(String code) =>
    CouponModel(id: code, code: code, discountValue: 10);

void main() {
  test('a cubit that is created is already loading', () {
    final cubit = CouponsCubit(repository: _FakeCoupons());
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.coupons, isEmpty);
  });

  group('loading', () {
    test('fills the list once the server answers', () async {
      final repository = _FakeCoupons(coupons: [coupon('A'), coupon('B')]);
      final cubit = CouponsCubit(repository: repository);
      await _settled(cubit);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.coupons.length, 2);
      expect(cubit.state.errorMessage, isNull);
      expect(repository.calls, 1);
      await cubit.close();
    });

    test('a server failure is reported and can be tried again', () async {
      final repository = _FakeCoupons(error: Exception('offline'));
      final cubit = CouponsCubit(repository: repository);
      await _settled(cubit);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, contains('offline'));

      repository.succeed();
      await cubit.load();
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.coupons, isEmpty);
      await cubit.close();
    });

    test('a retry clears the previous failure', () async {
      final repository = _FakeCoupons(error: Exception('offline'));
      final cubit = CouponsCubit(repository: repository);
      await _settled(cubit);
      repository.succeed(coupons: [coupon('A')]);
      await cubit.load();
      expect(cubit.state.coupons.length, 1);
      await cubit.close();
    });
  });
}

Future<void> _settled(CouponsCubit cubit) async {
  await cubit.stream.firstWhere((CouponsState state) => !state.isLoading);
}
