import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/tables/presentation/widgets/customer_event_requests_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'event requests are visible to floor readers without write actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerEventRequestsPanel(
              requests: [
                {
                  'id': 'event-1',
                  'occasion_type': 'birthday',
                  'status': 'pending',
                  'guest_count': 12,
                  'requested_space_type': 'any',
                  'preferred_start_at': '2026-12-10T15:00:00Z',
                  'customer_name': 'عميل',
                  'customer_phone': '0500000000',
                  'branch_name_ar': 'فرع المعادي',
                },
              ],
              tables: const [],
              canManage: false,
              onOffer: ({
                required id,
                required amount,
                required List<String> spaceIds,
                required startAt,
                required endAt,
                note,
              }) async => false,
              onReject: (_) async => false,
            ),
          ),
        ),
      );

      expect(find.textContaining('عيد ميلاد'), findsOneWidget);
      expect(find.text('إرسال عرض'), findsNothing);
      expect(find.text('رفض الطلب'), findsNothing);
    },
  );

  testWidgets('an empty queue says so instead of drawing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerEventRequestsPanel(
            requests: const [],
            tables: const [],
            canManage: true,
            onOffer: ({
              required id,
              required amount,
              required List<String> spaceIds,
              required startAt,
              required endAt,
              note,
            }) async => false,
            onReject: (_) async => false,
          ),
        ),
      ),
    );

    expect(find.text(S.eventRequestsEmpty), findsOneWidget);
  });

  testWidgets(
    'wide screens place up to five cards side by side at content height',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1400,
                child: CustomerEventRequestsPanel(
                  requests: [
                    for (var i = 0; i < 6; i++)
                      {
                        'id': 'event-$i',
                        'occasion_type': 'birthday',
                        'status': 'pending',
                        'guest_count': 12,
                        'requested_space_type': 'any',
                        'preferred_start_at': '2026-12-10T15:00:00Z',
                        'customer_name': 'عميل',
                        'customer_phone': '0500000000',
                        'branch_name_ar': 'فرع المعادي',
                      },
                  ],
                  tables: const [],
                  canManage: false,
                  onOffer: ({
                    required id,
                    required amount,
                    required List<String> spaceIds,
                    required startAt,
                    required endAt,
                    note,
                  }) async => false,
                  onReject: (_) async => false,
                ),
              ),
            ),
          ),
        ),
      );

      final cards = find.byType(InkWell);
      expect(cards, findsNWidgets(6));
      final first = tester.getRect(cards.at(0));
      final last = tester.getRect(cards.at(4));
      expect(first.top, last.top, reason: 'first five share one row');
      expect(first.width, closeTo(last.width, 0.01));
      expect(tester.getRect(cards.at(5)).top, greaterThan(first.top));
      expect(first.height, lessThan(420), reason: 'card fits its content');
    },
  );
}
