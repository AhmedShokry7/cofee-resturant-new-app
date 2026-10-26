import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/models/loyalty_filters.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_directory.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

AdminLoyaltyOverview _overview() => const AdminLoyaltyOverview(
  rule: AdminLoyaltyRule(
    id: 'rule-1',
    code: 'EARN',
    nameAr: 'برنامج الكسب',
    nameEn: 'Earning program',
    pointsPerCurrencyUnit: 1,
    pointValue: 0.05,
    isActive: true,
    isCurrent: true,
  ),
  members: 6,
  membersWithPoints: 4,
  pointsOutstanding: 740,
  pointsEarned: 1500,
  pointsRedeemed: 760,
  redemptions: 5,
  activeRewards: 2,
  totalRewards: 3,
  outOfStockRewards: 1,
  transactions: 4,
);

AdminLoyaltyReward _reward(
  int index, {
  bool isActive = true,
  int? stock = 5,
  bool available = true,
  AdminLoyaltyRewardType type = AdminLoyaltyRewardType.product,
}) => AdminLoyaltyReward(
  id: 'r$index',
  type: type,
  targetId: 'prod-$index',
  pointsCost: 50 * index,
  stockAvailable: stock,
  isActive: isActive,
  targetNameAr: 'منتج $index',
  targetNameEn: 'Reward $index',
  targetCode: 'SKU-$index',
  targetPrice: 20,
  targetIsAvailable: available,
  categoryNameEn: 'Hot coffee',
  bundleItemsCount: type == AdminLoyaltyRewardType.bundle ? 3 : 0,
  planDurationDays: type == AdminLoyaltyRewardType.plan ? 30 : null,
  planCupsPerCycle: type == AdminLoyaltyRewardType.plan ? 10 : null,
  redemptionsCount: index.isEven ? 2 : 0,
);

AdminLoyaltyMember _member(int index, {int points = 100}) => AdminLoyaltyMember(
  userId: 'u$index',
  fullName: 'Member $index',
  email: 'member$index@example.com',
  pointsBalance: points,
  lifetimePoints: points + 50,
  tier: index.isEven ? 'gold' : 'silver',
  redemptionsCount: 1,
  lastActivityAt: DateTime(2026, 5, index + 1),
);

AdminLoyaltyTransaction _transaction(
  int index, {
  String reason = 'earn_order',
  int points = 20,
}) => AdminLoyaltyTransaction(
  id: 't$index',
  userId: 'u$index',
  points: points,
  balanceAfter: 120,
  reason: reason,
  customerName: 'Member $index',
  orderNumber: 'ORD-${100 + index}',
  createdAt: DateTime(2026, 5, index + 1),
);

void _setViewport(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  List<AdminLoyaltyReward> rewards = const [],
  List<AdminLoyaltyMember> members = const [],
  List<AdminLoyaltyTransaction> transactions = const [],
  int? transactionsTotal,
  String search = '',
  bool canManage = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  VoidCallback? onEditRule,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: LoyaltyPageBody(
          overview: _overview(),
          canManage: canManage,
          onAdd: () {},
          onEditRule: onEditRule ?? () {},
          directory: LoyaltyDirectory(
            rewards: rewards,
            members: members,
            transactions: transactions,
            transactionsTotal: transactionsTotal ?? transactions.length,
            search: search,
            onSearchChanged: (_) {},
            canManage: canManage,
            onAdd: () {},
            onEdit: (_) {},
            onToggle: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openFilter<T>(
  WidgetTester tester,
  String label,
  String option,
) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PopupMenuItem<T>, option));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the narrow page shows the metrics, program and reward cards', (
    tester,
  ) async {
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1), _reward(2), _reward(3)],
      members: [_member(1), _member(2)],
      transactions: [_transaction(1)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.loyalty), findsOneWidget);
    expect(find.text(S.loyaltyMetricMembers), findsOneWidget);
    expect(find.text(S.loyaltyMetricPointsOutstanding), findsOneWidget);
    expect(find.text(S.loyaltyProgramTitle), findsOneWidget);
    expect(find.text(S.loyaltyTabRewards), findsOneWidget);
    expect(find.text(S.loyaltyTabMembers), findsOneWidget);
    expect(find.text(S.loyaltyTabActivity), findsOneWidget);
    expect(find.text(S.loyaltyAddReward), findsOneWidget);
    expect(find.text('Reward 1'), findsOneWidget);
    expect(find.text('Reward 2'), findsOneWidget);
    expect(find.byType(AdminPageFrame), findsOneWidget);
  });

  testWidgets('the narrow members and activity tabs use cards', (tester) async {
    _setViewport(tester, 420, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1)],
      members: [_member(1), _member(2)],
      transactions: [_transaction(1, reason: 'earn_order')],
    );

    await tester.tap(find.text(S.loyaltyTabMembers));
    await tester.pumpAndSettle();
    expect(find.text('Member 1'), findsOneWidget);
    expect(find.text(S.loyaltyMemberColumn), findsNothing);

    await tester.ensureVisible(find.text(S.loyaltyTabActivity));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.loyaltyTabActivity));
    await tester.pumpAndSettle();
    expect(find.text('Member 1'), findsOneWidget);
    expect(find.text(S.loyaltyActivityReasonEarn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wide members tab shows the table columns', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1)],
      members: [_member(1), _member(2), _member(3)],
    );

    await tester.tap(find.text(S.loyaltyTabMembers));
    await tester.pumpAndSettle();

    expect(find.text(S.loyaltyMemberColumn), findsOneWidget);
    expect(find.text(S.loyaltyBalanceColumn), findsOneWidget);
    expect(find.text(S.loyaltyLifetimeColumn), findsOneWidget);
    expect(find.text(S.loyaltyTierColumn), findsOneWidget);
    expect(find.text('Member 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wide activity tab shows the ledger columns', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1)],
      transactions: [
        _transaction(1),
        _transaction(2, reason: 'redeem_reward', points: -100),
      ],
    );

    await tester.tap(find.text(S.loyaltyTabActivity));
    await tester.pumpAndSettle();

    expect(find.text(S.loyaltyMovementColumn), findsOneWidget);
    expect(find.text(S.loyaltyPointsColumn), findsOneWidget);
    expect(find.text(S.loyaltyBalanceAfterColumn), findsOneWidget);
    expect(find.text(S.loyaltyDateColumn), findsOneWidget);
    expect(find.text(S.loyaltyActivityReasonEarn), findsOneWidget);
    expect(find.text(S.loyaltyActivityReasonRedeem), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the activity window note explains a partial feed', (
    tester,
  ) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1)],
      transactions: [_transaction(1), _transaction(2)],
      transactionsTotal: 10,
    );

    await tester.tap(find.text(S.loyaltyTabActivity));
    await tester.pumpAndSettle();

    expect(
      find.text(localizeDigits(S.loyaltyActivityShowingNewest(2, 10))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the paused reward filter hides the active rewards', (
    tester,
  ) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1), _reward(2, isActive: false), _reward(3, stock: 0)],
    );

    await _openFilter<LoyaltyRewardFilter>(
      tester,
      S.loyaltyRewardFilter,
      S.loyaltyRewardFilterPaused,
    );

    expect(find.text('Reward 2'), findsOneWidget);
    expect(find.text('Reward 1'), findsNothing);
    expect(find.text('Reward 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the search hides the rewards that do not match', (tester) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(tester, rewards: [_reward(1), _reward(2)], search: 'SKU-2');

    expect(find.text('Reward 2'), findsOneWidget);
    expect(find.text('Reward 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty catalogue offers to add the first reward', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, rewards: const []);

    expect(find.text(S.loyaltyNoRewards), findsOneWidget);
    expect(find.text(S.loyaltyAddReward), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a search with no result offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, rewards: [_reward(1)], search: 'missing');

    expect(find.text(S.loyaltyNoRewardsMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read-only manager sees the hint and no add action', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    await _pumpPage(tester, rewards: [_reward(1)], canManage: false);

    expect(find.text(S.loyaltyReadOnly), findsOneWidget);
    expect(find.text(S.loyaltyAddReward), findsNothing);
    expect(find.byTooltip(S.loyaltyRewardMenuTooltip), findsNothing);
    expect(find.byKey(const Key('loyalty-program-edit')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the program card exposes the edit action to managers', (
    tester,
  ) async {
    _setViewport(tester, 1280, 800);
    var edits = 0;
    await _pumpPage(tester, rewards: [_reward(1)], onEditRule: () => edits++);

    expect(find.byKey(const Key('loyalty-program-edit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('loyalty-program-edit')));
    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the coupon grid shows five cards per row on wide screens', (
    tester,
  ) async {
    _setViewport(tester, 1600, 1000);
    await _pumpPage(
      tester,
      rewards: [for (var index = 1; index <= 5; index++) _reward(index)],
    );

    final tops = [
      for (var index = 1; index <= 5; index++)
        tester.getTopLeft(find.byKey(Key('loyalty-reward-r$index'))).dy,
    ];
    expect(tops.toSet(), hasLength(1));
    expect(find.text(S.loyaltyPointUnit), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the coupon grid shows four cards per row on medium desktops', (
    tester,
  ) async {
    _setViewport(tester, 1100, 1000);
    await _pumpPage(
      tester,
      rewards: [for (var index = 1; index <= 5; index++) _reward(index)],
    );

    final firstRow = [
      for (var index = 1; index <= 4; index++)
        tester.getTopLeft(find.byKey(Key('loyalty-reward-r$index'))).dy,
    ];
    final fifthTop = tester
        .getTopLeft(find.byKey(const Key('loyalty-reward-r5')))
        .dy;
    expect(firstRow.toSet(), hasLength(1));
    expect(fifthTop, greaterThan(firstRow.first));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundle and plan rewards show their target type on the coupon', (
    tester,
  ) async {
    _setViewport(tester, 1440, 900);
    await _pumpPage(
      tester,
      rewards: [
        _reward(1),
        _reward(2, type: AdminLoyaltyRewardType.bundle),
        _reward(3, type: AdminLoyaltyRewardType.plan),
      ],
    );

    expect(find.textContaining(S.loyaltyRewardTypeBundle), findsOneWidget);
    expect(find.textContaining(S.loyaltyRewardTypePlan), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1), _reward(2)],
      members: [_member(1)],
      transactions: [_transaction(1)],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.loyalty), findsOneWidget);
    expect(find.text(S.loyaltyProgramTitle), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1280, 900);
    await _pumpPage(
      tester,
      rewards: [_reward(1), _reward(2)],
      members: [_member(1), _member(2)],
      dark: true,
    );

    await tester.tap(find.text(S.loyaltyTabMembers));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(S.loyaltyMemberColumn), findsOneWidget);
  });
}
