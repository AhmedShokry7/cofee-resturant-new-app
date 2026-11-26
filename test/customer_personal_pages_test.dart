import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/reservation_form_page.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/event_request_form_page.dart';
import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/product_subscription_form_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _json(Object body, http.Request request) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
  request: request,
);

void main() {
  tearDown(() {
    SupabaseService.debugSetClient(null);
    SupabaseService.debugSetSignedIn(false);
  });

  test('personal bundle model reads the last-used timestamp and items', () {
    final bundle = CustomerBundle.fromJson({
      'id': 'bundle-1',
      'user_id': 'user-1',
      'name': 'Morning set',
      'last_used_at': '2026-11-24T10:00:00Z',
      'items': [
        {'id': 'item-1', 'bundle_id': 'bundle-1', 'product_id': 'coffee-1'},
      ],
    });

    expect(bundle.lastUsedAt, DateTime.utc(2026, 11, 24, 10));
    expect(bundle.items.single.productId, 'coffee-1');
  });

  test('product subscription model reads recurrence and multiple items', () {
    final subscription = ProductSubscription.fromJson({
      'id': 'subscription-1',
      'status': 'active',
      'recurrence_type': 'daily',
      'interval_value': 2,
      'branch_id': 'branch-1',
      'pending_runs': [
        {
          'id': 'run-1',
          'scheduled_for': '2026-11-25T09:00:00Z',
          'status': 'pending',
        },
      ],
      'items': [
        {'product_id': 'coffee-1', 'quantity': 2},
        {'product_id': 'tea-1', 'quantity': 3},
      ],
    });

    expect(subscription.frequency, 'daily');
    expect(subscription.intervalValue, 2);
    expect(subscription.pendingRuns.single.id, 'run-1');
    expect(subscription.items.map((item) => item.quantity), [2, 3]);
  });

  test('reservation model falls back to the stored reserved-until value', () {
    final reservation = CustomerReservation.fromJson({
      'id': 'reservation-1',
      'branch_id': 'branch-1',
      'status': 'pending',
      'source': 'customer',
      'reserved_for': '2026-11-25T18:00:00Z',
      'reserved_until': '2026-11-25T20:00:00Z',
    });

    expect(reservation.requestedEndAt, DateTime.utc(2026, 11, 25, 20));
  });

  test('event request model reads the offer and selected space', () {
    final request = CustomerEventRequest.fromJson({
      'id': 'event-1',
      'occasion_type': 'graduation',
      'occasion_date': '2026-12-01',
      'preferred_start_at': '2026-12-01T15:00:00Z',
      'preferred_end_at': '2026-12-01T18:00:00Z',
      'guest_count': 24,
      'requested_space_type': 'room',
      'status': 'quoted',
      'branch_name_ar': 'فرع المعادي',
      'quote_amount': 2500,
      'quote_note': 'يشمل تجهيز الطاولة',
      'quoted_space_name': 'الغرفة الخاصة',
      'quoted_start_at': '2026-12-01T16:00:00Z',
      'quoted_end_at': '2026-12-01T19:00:00Z',
      'quote_expires_at': '2026-11-29T15:00:00Z',
    });

    expect(request.status, 'quoted');
    expect(request.guestCount, 24);
    expect(request.quoteAmount, 2500);
    expect(request.quotedSpaceName, 'الغرفة الخاصة');
    expect(request.branchName, 'فرع المعادي');
  });

  testWidgets(
    'event request form sends a structured future reservation request',
    (tester) async {
      Map<String, dynamic>? payload;
      final client = SupabaseClient(
        'https://customer-flow.test',
        'publishable-test-key',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/rest/v1/branches')) {
            return _json([
              {'id': 'branch-1', 'name_ar': 'فرع الاختبار', 'name_en': 'Test'},
            ], request);
          }
          if (request.url.path.endsWith(
            '/rest/v1/rpc/create_my_customer_event_request',
          )) {
            payload = (jsonDecode(request.body) as Map<String, dynamic>)
                .cast<String, dynamic>();
            return _json('event-1', request);
          }
          return _json({'message': 'Unexpected test request'}, request);
        }),
      );
      SupabaseService.debugSetClient(client);
      SupabaseService.debugSetSignedIn(true);

      await tester.pumpWidget(const MaterialApp(home: EventRequestFormPage()));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إرسال طلب المناسبة'));
      await tester.pumpAndSettle();

      expect(payload, isNotNull);
      final request = payload!['p_payload'] as Map<String, dynamic>;
      expect(request['branch_id'], 'branch-1');
      expect(request['occasion_type'], 'birthday');
      expect(request['requested_space_type'], 'any');
      expect(request['guest_count'], 10);
      expect(
        DateTime.parse(request['preferred_start_at'] as String)
            .isAfter(DateTime.now()),
        isTrue,
      );
    },
  );

  testWidgets(
    'product subscription form submits more than one selected product',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://customer-flow.test',
        'publishable-test-key',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/rest/v1/branches')) {
            return _json([
              {'id': 'branch-1', 'name_ar': 'Branch', 'name_en': 'Branch'},
            ], request);
          }
          if (request.url.path.endsWith('/rest/v1/products')) {
            return _json([
              {'id': 'coffee-1', 'name_ar': 'Coffee A', 'name_en': 'Coffee A'},
              {'id': 'tea-1', 'name_ar': 'Tea B', 'name_en': 'Tea B'},
            ], request);
          }
          if (request.url.path.endsWith(
            '/rest/v1/rpc/create_customer_product_subscription',
          )) {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return _json('subscription-1', request);
          }
          return _json({'message': 'Unexpected test request'}, request);
        }),
      );
      SupabaseService.debugSetClient(client);
      SupabaseService.debugSetSignedIn(true);

      await tester.pumpWidget(
        const MaterialApp(home: ProductSubscriptionFormPage()),
      );
      await tester.pumpAndSettle();
      for (final product in ['Coffee A', 'Tea B']) {
        await tester.drag(find.byType(ListView), const Offset(0, -550));
        await tester.pumpAndSettle();
        final tile = find.widgetWithText(CheckboxListTile, product);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final createButton = find.byType(FilledButton).last;
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(bodies, hasLength(1));
      final payload = bodies.single['p_payload'] as Map<String, dynamic>;
      expect(payload['recurrence_type'], 'weekly');
      expect(payload['interval_value'], 1);
      expect(
        DateTime.parse(payload['first_run_at'] as String)
            .isAfter(DateTime.now().toUtc()),
        isTrue,
      );
      expect(payload['items'], hasLength(2));
      expect(
        (payload['items'] as List)
            .map((item) => (item as Map<String, dynamic>)['product_id'])
            .toSet(),
        {'coffee-1', 'tea-1'},
      );
    },
  );

  testWidgets('reservation form loads and submits the selected room type', (
    tester,
  ) async {
    final bodies = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://customer-flow.test',
      'publishable-test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rest/v1/branches')) {
          return _json([
            {'id': 'branch-1', 'name_ar': 'Branch', 'name_en': 'Branch'},
          ], request);
        }
        if (request.url.path.endsWith(
          '/rest/v1/rpc/list_customer_reservation_spaces',
        )) {
          final params = jsonDecode(request.body) as Map<String, dynamic>;
          final type = params['p_reservation_type'] as String?;
          return _json([
            {
              'id': type == 'room' ? 'room-1' : 'table-1',
              'name': type == 'room' ? 'Room 1' : 'Table 1',
              'capacity': 4,
              'area': type == 'room' ? 'private_room' : 'hall',
            },
          ], request);
        }
        if (request.url.path.endsWith(
          '/rest/v1/rpc/create_customer_reservation',
        )) {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json('reservation-1', request);
        }
        return _json({'message': 'Unexpected test request'}, request);
      }),
    );
    SupabaseService.debugSetClient(client);
    SupabaseService.debugSetSignedIn(true);

    await tester.pumpWidget(const MaterialApp(home: ReservationFormPage()));
    await tester.pumpAndSettle();

    final dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    await tester.tap(find.byWidget(dropdowns[1]));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.roomReservation).last);
    await tester.pumpAndSettle();

    final spaceDropdowns = tester
        .widgetList<DropdownButtonFormField<String?>>(
          find.byType(DropdownButtonFormField<String?>),
        )
        .toList();
    await tester.tap(find.byWidget(spaceDropdowns.single));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Room 1 · 4').last);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(bodies, hasLength(1));
    final payload = bodies.single['p_payload'] as Map<String, dynamic>;
    expect(payload['reservation_type'], 'room');
    expect(payload['table_id'], 'room-1');
  });
}
