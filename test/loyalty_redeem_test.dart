// What one tap on "Redeem" is allowed to do, and what it says afterwards.
//
// `loyalty.redeem_loyalty_reward` takes no idempotency key, so the client is
// the only thing standing between two quick taps and two free orders. The
// outcomes below are also the reason a failed network stopped being reported to
// the customer as a shortage of points.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/widgets/reward_card.dart';

import 'support/mock_product_repository.dart';

class _FakeLoyaltyRepository implements LoyaltyRepository {
  _FakeLoyaltyRepository({
    this.rewards = const [],
    this.walletBalance = 100,
    this.asGuest = false,
  });

  final List<RewardModel> rewards;
  int walletBalance;

  /// Set when the spend must stay unanswered until the test lets it go.
  Completer<int>? redeemGate;

  /// Fail the spend the way the server does, with its own table names.
  bool redeemError = false;

  /// The ledger's own column values. The Arabic test is about none of them
  /// reaching the screen, so they are the fake's defaults rather than a knob.
  String tier = 'gold';
  int lifetimePoints = 800;

  /// Null wallet answer, which is how the repository reports "no account".
  final bool asGuest;

  int redeemCalls = 0;
  String? lastRewardId;
  String? lastBranchId;

  @override
  Future<LoyaltyCatalog> loadCatalog() async =>
      LoyaltyCatalog(rewards: rewards);

  @override
  Future<LoyaltyWallet?> loadWallet() async {
    if (asGuest) return null;
    return LoyaltyWallet(
      balance: walletBalance,
      tier: tier,
      lifetimePoints: lifetimePoints,
    );
  }

  @override
  Future<int> redeemReward({required String rewardId, String? branchId}) {
    redeemCalls++;
    lastRewardId = rewardId;
    lastBranchId = branchId;
    if (redeemError) {
      return Future.error(
        StateError(
          'redeem_loyalty_reward: relation "loyalty.rewards" '
          'does not exist',
        ),
      );
    }
    final gate = redeemGate;
    if (gate == null) return Future.value(walletBalance);
    return gate.future.then((balance) {
      walletBalance = balance;
      return balance;
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

RewardModel _bundleReward({int cost = 50}) => RewardModel(
  type: RewardTargetType.bundle,
  targetId: 'bundle-1',
  pointsCost: cost,
  id: 'reward-bundle',
  nameEn: 'Tasting bundle',
);

/// A product reward carries the full product: a guest device cart cannot
/// resolve a reward from an id alone.
Future<RewardModel> _latteReward() async {
  final product = (await MockProductRepository().getProducts()).first;
  return RewardModel(
    type: RewardTargetType.product,
    targetId: product.id,
    pointsCost: 40,
    id: 'reward-latte',
    product: product,
  );
}

/// Seed the device wallet so a guest reward is unlocked and tappable.
void _seedGuestWallet(int balance) {
  SharedPreferences.setMockInitialValues({
    _walletKey: '{"balance":$balance,"transactions":[]}',
  });
}

const _walletKey = 'loyalty_wallet_v1';

class _Page {
  _Page(this.cubit, this.cart);

  final LoyaltyCubit cubit;
  final CartCubit cart;
}

Future<_Page> _pumpPage(
  WidgetTester tester,
  LoyaltyRepository repository, {
  String? branchId,
}) async {
  tester.view.physicalSize = const Size(390, 900) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final cart = CartCubit(
    cartRepository: LocalCartRepository(),
    catalogRepository: MockProductRepository(),
  );
  addTearDown(cart.close);

  final cubit = LoyaltyCubit(repository: repository, branchId: branchId);
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider.value(value: cart)],
      child: MaterialApp(
        home: BlocProvider.value(value: cubit, child: const LoyaltyPage()),
      ),
    ),
  );
  await _flush(tester);
  return _Page(cubit, cart);
}

/// The page answers with plain futures, so a few frames carry every pending
/// microtask through without settling the shimmer that never ends.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('one tap spends once and a second tap does nothing', (
    tester,
  ) async {
    final repository = _FakeLoyaltyRepository(rewards: [_bundleReward()]);
    repository.redeemGate = Completer<int>();

    await _pumpPage(tester, repository, branchId: 'branch-1');

    expect(find.text('Tasting bundle'), findsOneWidget);
    await tester.tap(find.text(S.redeem));
    await tester.pump();

    expect(repository.redeemCalls, 1);
    // The card that started the spend stops offering another one.
    final busyCard = tester.widget<RewardCard>(find.byType(RewardCard));
    expect(busyCard.busy, isTrue);

    await tester.tap(find.text(S.redeem));
    await tester.pump();

    expect(
      repository.redeemCalls,
      1,
      reason: 'the server takes no idempotency key, so the client is the guard',
    );

    repository.redeemGate!.complete(40);
    await _flush(tester);
    await tester.pumpAndSettle();

    expect(find.text('40'), findsOneWidget);
    expect(find.text(S.rewardOrderCreated('Tasting bundle')), findsOneWidget);
  });

  testWidgets('a refusal is a refusal, not a shortage of points', (
    tester,
  ) async {
    final repository = _FakeLoyaltyRepository(rewards: [_bundleReward()]);
    repository.redeemError = true;

    await _pumpPage(tester, repository, branchId: 'branch-1');

    await tester.tap(find.text(S.redeem));
    await _flush(tester);
    await tester.pumpAndSettle();

    expect(find.text(S.couldNotRedeemReward), findsOneWidget);
    expect(
      find.text(S.notEnoughPoints),
      findsNothing,
      reason: 'the customer has the points; blaming them would be wrong',
    );
    expect(
      find.text(S.couldNotRefreshWallet),
      findsNothing,
      reason: 'one failed spend must not be announced twice',
    );
    expect(
      find.textContaining('loyalty.rewards'),
      findsNothing,
      reason: 'the server\'s own words stay off the screen',
    );
    expect(find.text('100'), findsOneWidget, reason: 'no points were spent');
    expect(await _walletWritten(), isFalse);
  });

  test('a short balance is refused before anything is written', () async {
    final repository = _FakeLoyaltyRepository(
      rewards: [_bundleReward(cost: 50)],
      walletBalance: 20,
    );
    final cubit = LoyaltyCubit(repository: repository, branchId: 'branch-1');
    addTearDown(cubit.close);
    await cubit.settled();

    expect(await cubit.redeem(_bundleReward()), RedeemOutcome.notEnoughPoints);
    expect(cubit.state.balance, 20);
    expect(
      repository.redeemCalls,
      0,
      reason: 'the server is never asked to spend points that are not there',
    );
  });

  test(
    'a spend that is already in flight answers the second tap with nothing',
    () async {
      final repository = _FakeLoyaltyRepository(walletBalance: 100);
      repository.redeemGate = Completer<int>();
      final cubit = LoyaltyCubit(repository: repository, branchId: 'branch-1');
      addTearDown(cubit.close);
      await cubit.settled();

      final reward = _bundleReward();
      final first = cubit.redeem(reward);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isRedeeming, isTrue);

      expect(await cubit.redeem(reward), RedeemOutcome.inProgress);
      expect(repository.redeemCalls, 1);

      repository.redeemGate!.complete(60);
      await first;
      expect(cubit.state.isRedeeming, isFalse, reason: 'the guard resets');
    },
  );

  testWidgets('a branch reward with no branch says to pick one', (
    tester,
  ) async {
    final repository = _FakeLoyaltyRepository(rewards: [_bundleReward()]);

    await _pumpPage(tester, repository);

    await tester.tap(find.text(S.redeem));
    await _flush(tester);
    await tester.pumpAndSettle();

    expect(find.text(S.selectBranchBeforeRedeeming), findsOneWidget);
    expect(
      repository.redeemCalls,
      0,
      reason: 'a free order has to be addressed somewhere',
    );
  });

  testWidgets('a guest cannot redeem a bundle and is told to sign in', (
    tester,
  ) async {
    _seedGuestWallet(120);
    final repository = _FakeLoyaltyRepository(
      rewards: [_bundleReward()],
      asGuest: true,
    );

    await _pumpPage(tester, repository, branchId: 'branch-1');

    expect(find.text('120'), findsOneWidget);
    await tester.tap(find.text(S.redeem));
    await _flush(tester);
    await tester.pumpAndSettle();

    expect(find.text(S.rewardRequiresAccount), findsOneWidget);
    expect(repository.redeemCalls, 0);
    expect(
      find.text('120'),
      findsOneWidget,
      reason: 'a reward the device cannot hold costs the device nothing',
    );
  });

  testWidgets('a guest product lands in the cart at no price', (tester) async {
    _seedGuestWallet(120);
    final reward = await _latteReward();
    final repository = _FakeLoyaltyRepository(rewards: [reward], asGuest: true);

    final page = await _pumpPage(tester, repository);

    await tester.tap(find.text(S.redeem));
    await _flush(tester);
    await tester.pumpAndSettle();

    expect(page.cart.state.items.length, 1);
    expect(page.cart.state.items.single.quantity, 1);
    expect(page.cubit.state.balance, 80);
    expect(find.text(S.enjoyReward(reward.name)), findsOneWidget);
  });

  testWidgets('the tier is the word the customer reads, not the column value', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    final repository = _FakeLoyaltyRepository(rewards: [_bundleReward()]);

    await _pumpPage(tester, repository, branchId: 'branch-1');

    expect(
      find.text(
        S.lifetimePoints(
          S.tierLabel(repository.tier),
          repository.lifetimePoints,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(repository.tier),
      findsNothing,
      reason: 'the database word for the tier never reaches an Arabic screen',
    );
  });

  testWidgets('a reward that is not affordable has no way to spend it', (
    tester,
  ) async {
    final repository = _FakeLoyaltyRepository(
      rewards: [_bundleReward(cost: 900)],
      walletBalance: 30,
    );

    await _pumpPage(tester, repository, branchId: 'branch-1');

    expect(find.text(S.locked), findsOneWidget);
    expect(find.text(S.redeem), findsNothing);

    // The card is set back by its own surface, not by dimming the text under it.
    final card = tester.widget<RewardCard>(find.byType(RewardCard));
    expect(card.locked, isTrue);
    expect(
      find.ancestor(
        of: find.byType(RewardCard),
        matching: find.byType(Opacity),
      ),
      findsNothing,
      reason:
          'an Opacity over the subtree is what took the words below the '
          'contrast a customer needs',
    );
  });

  testWidgets('the redeem pill is a target, not a line of text', (
    tester,
  ) async {
    final repository = _FakeLoyaltyRepository(rewards: [_bundleReward()]);

    await _pumpPage(tester, repository, branchId: 'branch-1');

    // The announcement names both the action and the reward it acts on, and
    // that same control is the target a thumb has to hit.
    final pill = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label == '${S.redeem}: Tasting bundle',
    );
    expect(pill, findsOneWidget);

    final size = tester.getSize(pill);
    expect(
      size.height,
      greaterThanOrEqualTo(AppDimensions.tapTargetMin),
      reason: 'the only way to spend this reward must be tappable by thumb',
    );
  });
}

/// The fake repository is the only writer, so the device wallet can only move
/// if the guest path ran.
Future<bool> _walletWritten() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_walletKey);
}

extension on LoyaltyCubit {
  /// The constructor loads without exposing the future.
  Future<void> settled() async {
    for (var i = 0; i < 20 && state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}
