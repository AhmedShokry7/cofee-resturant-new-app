import 'package:new_coffee/shared/widgets/app_back_button.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/my_product_subscriptions_page.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/product_subscription_summary_card.dart';

void main() {
  tearDown(() {
    SupabaseService.debugSetClient(null);
    SupabaseService.debugSetSignedIn(false);
  });
  testWidgets(
    'product summary opens only the selected subscription and exposes its due order',
    (tester) async {
      final client = SupabaseClient(
        'https://subscriptions.test',
        'test-key',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
        ),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'id': 'one',
                'branch_id': 'branch',
                'name': 'Morning coffee',
                'status': 'active',
                'recurrence_type': 'daily',
                'items': [
                  {
                    'product_id': 'coffee',
                    'quantity': 2,
                    'product_name_en': 'Coffee',
                    'product_name_ar': 'قهوة',
                  },
                ],
                'pending_runs': [
                  {'id': 'run', 'scheduled_for': '2026-11-26T10:00:00Z'},
                ],
              },
              {
                'id': 'two',
                'branch_id': 'branch',
                'name': 'Weekend coffee',
                'status': 'active',
                'recurrence_type': 'weekly',
              },
              {
                'id': 'cancelled',
                'branch_id': 'branch',
                'name': 'Cancelled coffee',
                'status': 'cancelled',
                'recurrence_type': 'daily',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      SupabaseService.debugSetClient(client);
      SupabaseService.debugSetSignedIn(true);
      await tester.pumpWidget(
        const MaterialApp(home: MyProductSubscriptionsPage()),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ProductSubscriptionSummaryCard),
        findsNWidgets(2),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(find.text('Cancelled coffee'), findsNothing);
      await tester.tap(find.text('Morning coffee'));
      await tester.pumpAndSettle();
      expect(find.text('Weekend coffee'), findsNothing);
      expect(find.text(S.productSubscriptions), findsOneWidget);
      expect(find.text(S.productSubscriptionOrderDue), findsOneWidget);
      await tester.scrollUntilVisible(find.text(S.reviewAndConfirmOrder), 150);
      expect(find.text(S.reviewAndConfirmOrder), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(
        find.byType(ProductSubscriptionSummaryCard),
        findsNWidgets(2),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
    },
  );
}
