import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_cubit.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/pages/subscription_plan_page.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_cubit.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/pages/subscription_admin_page.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the plans page renders with its own cubit and no provider', (
    tester,
  ) async {
    final cubit = AdminSubscriptionPlanCubit();
    addTearDown(cubit.close);
    final search = AdminSearchController();
    addTearDown(search.dispose);

    await _pump(
      tester,
      SubscriptionPlanPage(searchController: search, cubit: cubit),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionPlans), findsOneWidget);
    expect(find.text(S.noSubscriptionPlans), findsOneWidget);
  });

  testWidgets(
    'the subscriptions page renders with its own cubit and no provider',
    (tester) async {
      final cubit = AdminSubscriptionCubit();
      addTearDown(cubit.close);
      final search = AdminSearchController();
      addTearDown(search.dispose);

      await _pump(
        tester,
        SubscriptionAdminPage(searchController: search, cubit: cubit),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.subscriptions), findsOneWidget);
      expect(find.text(S.noSubscriptions), findsOneWidget);
    },
  );
}
