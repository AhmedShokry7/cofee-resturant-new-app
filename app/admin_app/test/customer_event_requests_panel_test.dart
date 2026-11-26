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
}
