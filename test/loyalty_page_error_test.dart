// What the loyalty page says when the server refuses to answer.
//
// A wallet that could not be read looks identical to a customer with no points
// unless the page says otherwise, and the reward list is public reference data
// that a failed wallet read must not throw away.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';

class _LoyaltyRepositoryDouble implements LoyaltyRepository {
  _LoyaltyRepositoryDouble({
    this.rewards = const [],
    this.catalogError = false,
  });

  final List<RewardModel> rewards;

  /// Fails the wallet read on every call after the first, standing in for a
  /// session that expired between two loads.
  bool walletError = false;
  final bool catalogError;

  @override
  Future<LoyaltyCatalog> loadCatalog() async {
    if (catalogError) throw StateError('loyalty_rewards: permission denied');
    return LoyaltyCatalog(rewards: rewards);
  }

  @override
  Future<LoyaltyWallet?> loadWallet() async {
    if (walletError) throw StateError('user_points: permission denied');
    return LoyaltyWallet(balance: 100, tier: 'bronze', lifetimePoints: 100);
  }

  @override
  Future<int> redeemReward({required String rewardId, String? branchId}) =>
      Future.value(0);
}

final _reward = RewardModel(
  type: RewardTargetType.bundle,
  targetId: 'bundle-1',
  pointsCost: 50,
  id: 'r1',
  nameEn: 'Free bundle',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPage(WidgetTester tester, LoyaltyCubit cubit) async {
    tester.view.physicalSize = const Size(360, 690) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: LoyaltyPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'a refused wallet read is not shown as a customer with no points',
    (tester) async {
      final cubit = LoyaltyCubit(
        repository: _LoyaltyRepositoryDouble(catalogError: true),
      );
      addTearDown(cubit.close);

      await pumpPage(tester, cubit);

      expect(find.text(S.couldNotLoadLoyalty), findsOneWidget);
      expect(find.text(S.keepCollectingToUnlock), findsNothing);
      expect(find.text(S.yourBalance), findsNothing);
    },
  );

  testWidgets('a failed refresh keeps the rewards and says what failed', (
    tester,
  ) async {
    final repository = _LoyaltyRepositoryDouble(rewards: [_reward]);
    final cubit = LoyaltyCubit(repository: repository);
    addTearDown(cubit.close);

    await pumpPage(tester, cubit);
    expect(find.text('Free bundle'), findsOneWidget);

    repository.walletError = true;
    await cubit.load();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Free bundle'),
      findsOneWidget,
      reason: 'the reward list is reference data, not part of the wallet',
    );
    expect(find.text(S.couldNotRefreshWallet), findsOneWidget);
    expect(
      find.textContaining('user_points'),
      findsNothing,
      reason:
          'the table that refused is the backend\'s business, not the '
          'customer\'s',
    );
  });

  test('a wallet failure lands in state, not only in the observer', () async {
    final cubit = LoyaltyCubit(
      repository: _LoyaltyRepositoryDouble(catalogError: true),
    );
    addTearDown(cubit.close);
    await cubit.settledIfAny();

    expect(cubit.state.error, contains('loyalty_rewards'));
    expect(cubit.state.isLoading, isFalse);
  });
}

extension on LoyaltyCubit {
  /// The constructor loads without exposing the future, so a test waits for the
  /// state to stop reporting a load.
  Future<void> settledIfAny() async {
    for (var i = 0; i < 20 && state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}
