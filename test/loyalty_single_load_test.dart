import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';

/// A ledger whose first wallet read is held open, so a slow earlier load can be
/// made to land after a faster later one.
class _ScriptedLoyaltyRepository implements LoyaltyRepository {
  int catalogCalls = 0;
  int walletCalls = 0;
  final List<Completer<void>> pending = [];

  @override
  Future<LoyaltyCatalog> loadCatalog() async {
    catalogCalls++;
    return const LoyaltyCatalog();
  }

  @override
  Future<LoyaltyWallet?> loadWallet() {
    final call = walletCalls++;
    if (call > 0) {
      return Future.value(
        LoyaltyWallet(balance: 99, tier: 'fresh', lifetimePoints: 500),
      );
    }
    final gate = Completer<void>();
    pending.add(gate);
    return gate.future.then(
      (_) => LoyaltyWallet(balance: 10, tier: 'stale', lifetimePoints: 20),
    );
  }

  @override
  Future<int> redeemReward({
    required String productId,
    required String branchId,
  }) => Future.value(0);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the constructor is the only initial load', () async {
    final repository = _ScriptedLoyaltyRepository();
    final cubit = LoyaltyCubit(repository: repository);
    addTearDown(cubit.close);

    // Load #1 is parked inside loadWallet; count the reads it has issued.
    await Future<void>.delayed(Duration.zero);
    expect(repository.catalogCalls, 1);
    expect(repository.walletCalls, 1);

    final settled = cubit.stream.firstWhere((state) => !state.isLoading);
    repository.pending.single.complete();
    await settled;

    // A deliberate reload still costs exactly one more pair of reads.
    await cubit.load();
    expect(repository.catalogCalls, 2);
    expect(repository.walletCalls, 2);
  });

  test('an overlapping slower load never overwrites the newer answer', () async {
    final repository = _ScriptedLoyaltyRepository();

    // Load #1 is parked inside loadWallet and will answer with the stale
    // balance 10.
    final cubit = LoyaltyCubit(repository: repository);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    expect(repository.walletCalls, 1);

    // Load #2 answers immediately with the fresh balance 99.
    await cubit.load();
    expect(cubit.state.balance, 99);
    expect(cubit.state.tier, 'fresh');

    // Now the stale answer finally lands. It must be discarded.
    repository.pending.single.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(cubit.state.balance, 99, reason: 'a stale answer must not win');
    expect(cubit.state.tier, 'fresh');
    expect(cubit.state.lifetimePoints, 500);
  });

  test('three overlapping loads settle on the newest one', () async {
    final repository = _ScriptedLoyaltyRepository();
    final cubit = LoyaltyCubit(repository: repository);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final second = cubit.load();
    final third = cubit.load();
    await Future.wait([second, third]);

    repository.pending.single.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(cubit.state.balance, 99);
    expect(cubit.state.isLoading, isFalse);
  });

  test('a guest wallet is still read and never mixed with a server one', () async {
    final repository = _ScriptedLoyaltyRepository();
    final cubit = LoyaltyCubit(repository: repository);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    repository.pending.single.complete();
    await cubit.load();

    expect(cubit.state.isGuest, isFalse);
    expect(cubit.state.balance, 99);
    expect(cubit.state.transactions, isEmpty);
  });
}