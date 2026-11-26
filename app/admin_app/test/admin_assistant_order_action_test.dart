import 'package:admin_app/features/admin_assistant/data/admin_assistant_order_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assistant order lifecycle command understanding', () {
    test('recognizes Arabic and English status changes', () {
      expect(
        AdminAssistantOrderAction.isStatusChangeIntent(
          'غيّر حالة الطلب POS-2026-000123 إلى قيد التحضير',
        ),
        isTrue,
      );
      expect(
        AdminAssistantOrderAction.isStatusChangeIntent(
          'Change order status POS-2026-000123 to ready',
        ),
        isTrue,
      );
      expect(
        AdminAssistantOrderAction.isStatusChangeIntent(
          'What is the status of order POS-2026-000123?',
        ),
        isFalse,
      );
    });

    test('maps only known database statuses', () {
      expect(
        AdminAssistantOrderAction.requestedTargetStatus('إلى قيد التحضير'),
        'preparing',
      );
      expect(
        AdminAssistantOrderAction.requestedTargetStatus(
          'set it out for delivery',
        ),
        'out_for_delivery',
      );
      expect(
        AdminAssistantOrderAction.requestedTargetStatus('خليه ملغي'),
        isNull,
      );
    });

    test('recognizes cancellation requests separately from refunds', () {
      expect(
        AdminAssistantOrderAction.isCancellationIntent(
          'ألغِ الطلب POS-2026-000123 بسبب طلب العميل',
        ),
        isTrue,
      );
      expect(
        AdminAssistantOrderAction.isCancellationIntent(
          'Cancel order POS-2026-000123 because customer requested it',
        ),
        isTrue,
      );
      expect(
        AdminAssistantOrderAction.isCancellationIntent(
          'Refund order POS-2026-000123',
        ),
        isFalse,
      );
    });
  });
}
