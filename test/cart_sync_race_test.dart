import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

/// A cart backend that records every write and can be held open, so the
/// ordering and the identity carried by each write can be observed.
class RecordingCartRepository implements CartRepository {
  final List<List<CartLine>> writes = <List<CartLine>>[];
  final List<String> writeIdentities = <String>[];
  final List<Completer<void>> _gates = <Completer<void>>[];
  int _inFlight = 0;
  int maxConcurrentWrites = 0;

  /// When true every write waits for [release] before answering.
  bool holdWrites = false;

  String Function()? identityOf;

  void release() {
    for (final gate in _gates) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<List<CartLine>?> fetchLines({String? branchId}) async =>
      const <CartLine>[];

  @override
  Future<void> saveLines({
    String? branchId,
    required List<CartLine> lines,
  }) async {
    writes.add(List<CartLine>.of(lines));
    writeIdentities.add(identityOf?.call() ?? '');
    _inFlight++;
    if (_inFlight > maxConcurrentWrites) maxConcurrentWrites = _inFlight;
    try {
      if (holdWrites) {
        final gate = Completer<void>();
        _gates.add(gate);
        await gate.future;
      }
    } finally {
      _inFlight--;
    }
  }
}

void main() {
  const latte = ProductModel(
    id: '3',
    name: 'Latte',
    category: 'Hot Coffee',
    description: 'd',
    price: 35,
    image: 'x',
  );

  late RecordingCartRepository repo;
  late String identity;
  late CartCubit cubit;

  CartCubit build() {
    final built = CartCubit(
      cartRepository: repo,
      catalogRepository: MockProductRepository(),
      branchId: 'branch-1',
      userIdProvider: () => identity,
    );
    addTearDown(built.close);
    return built;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repo = RecordingCartRepository()..identityOf = () => identity;
    identity = 'user-a';
  });

  test('a queued write never outlives an account switch', () async {
    cubit = build();
    await cubit.settled;

    cubit.add(latte);
    // The customer signs in as somebody else before the debounce closed.
    identity = 'user-b';
    cubit.applyIdentityTransition('user-b');

    await Future<void>.delayed(const Duration(milliseconds: 900));

    // The stale timer must not write the new account's empty cart.
    expect(repo.writes, isEmpty);
  });

  test('two cart changes never reach the server out of order', () async {
    cubit = build();
    await cubit.settled;

    repo.holdWrites = true;
    cubit.add(latte, quantity: 1);
    final first = cubit.flushServerSync();
    cubit.add(latte, quantity: 1);
    final second = cubit.flushServerSync();

    await Future<void>.delayed(Duration.zero);
    expect(repo.maxConcurrentWrites, 1);
    repo.holdWrites = false;
    repo.release();
    await Future.wait([first, second]);

    expect(repo.maxConcurrentWrites, 1);
    expect(repo.writes.length, greaterThanOrEqualTo(1));
    expect(repo.writes.last.single.quantity, 2);
  });
}
