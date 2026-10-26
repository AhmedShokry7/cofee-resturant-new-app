import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_format.dart';

AdminKitchenTicketItem _item({
  String optionGroupAr = '',
  String optionGroupEn = '',
  List<AdminKitchenOption> options = const <AdminKitchenOption>[],
}) => AdminKitchenTicketItem(
  id: 'i1',
  productNameAr: 'فلات وايت',
  productNameEn: 'Flat white',
  optionGroupNameAr: optionGroupAr,
  optionGroupNameEn: optionGroupEn,
  options: options,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('labels', () {
    test('ticket statuses have board and pill labels', () {
      expect(
        kitchenStatusLabel(KitchenTicketStatus.queued),
        S.kitchenStatusQueued,
      );
      expect(
        kitchenStatusLabel(KitchenTicketStatus.preparing),
        S.statusPreparing,
      );
      expect(kitchenStatusLabel(KitchenTicketStatus.ready), S.statusReady);
      expect(
        kitchenStatusLabel(KitchenTicketStatus.completed),
        S.kitchenStatusCompleted,
      );
      expect(
        kitchenStatusLabel(KitchenTicketStatus.cancelled),
        S.statusCancelled,
      );

      expect(
        kitchenColumnLabel(KitchenTicketStatus.queued),
        S.kitchenColumnQueued,
      );
      expect(
        kitchenColumnLabel(KitchenTicketStatus.preparing),
        S.kitchenColumnPreparing,
      );
      expect(
        kitchenColumnLabel(KitchenTicketStatus.ready),
        S.kitchenColumnReady,
      );
      expect(
        kitchenColumnLabel(KitchenTicketStatus.completed),
        S.kitchenColumnCompleted,
      );
    });

    test('the four board columns are queued, preparing, ready, completed', () {
      expect(kKitchenBoardStatuses, <KitchenTicketStatus>[
        KitchenTicketStatus.queued,
        KitchenTicketStatus.preparing,
        KitchenTicketStatus.ready,
        KitchenTicketStatus.completed,
      ]);
    });

    test('status colors and icons are distinct', () {
      expect(
        kitchenStatusColor(KitchenTicketStatus.queued),
        AppColor.adminWarning,
      );
      expect(
        kitchenStatusColor(KitchenTicketStatus.preparing),
        AppColor.adminInfo,
      );
      expect(
        kitchenStatusColor(KitchenTicketStatus.ready),
        AppColor.trendPositive,
      );
      expect(
        kitchenStatusColor(KitchenTicketStatus.completed),
        AppColor.adminMuted,
      );
      expect(
        kitchenStatusColor(KitchenTicketStatus.cancelled),
        AppColor.trendNegative,
      );

      final icons = {
        for (final status in KitchenTicketStatus.values)
          kitchenStatusIcon(status),
      };
      expect(icons, hasLength(KitchenTicketStatus.values.length));
    });

    test('item statuses explain what is left to do', () {
      expect(
        kitchenItemStatusLabel(KitchenItemStatus.pending),
        S.kitchenItemPending,
      );
      expect(
        kitchenItemStatusLabel(KitchenItemStatus.preparing),
        S.statusPreparing,
      );
      expect(
        kitchenItemStatusLabel(KitchenItemStatus.ready),
        S.kitchenItemReady,
      );
    });

    test('fulfillment types pick the right label and icon', () {
      expect(kitchenFulfillmentLabel('delivery'), S.fulfillmentDelivery);
      expect(kitchenFulfillmentLabel('dine_in'), S.kitchenDineIn);
      expect(kitchenFulfillmentLabel('pickup'), S.fulfillmentPickup);
      expect(kitchenFulfillmentLabel('anything'), S.fulfillmentPickup);
      expect(kitchenFulfillmentLabel(''), S.fulfillmentPickup);

      expect(
        kitchenFulfillmentIcon('delivery'),
        isNot(kitchenFulfillmentIcon('dine_in')),
      );
      expect(
        kitchenFulfillmentIcon('dine_in'),
        isNot(kitchenFulfillmentIcon('pickup')),
      );
    });

    test('order source tells online orders from the point of sale', () {
      expect(kitchenSourceLabel('pos'), S.kitchenSourcePos);
      expect(kitchenSourceLabel('online'), S.kitchenSourceOnline);
      expect(kitchenSourceLabel(''), S.kitchenSourceOnline);
      expect(kitchenSourceIcon('pos'), isNot(kitchenSourceIcon('online')));
    });

    test('labels follow the Arabic language', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);

      expect(kitchenStatusLabel(KitchenTicketStatus.queued), 'جديدة');
      expect(kitchenColumnLabel(KitchenTicketStatus.ready), 'جاهزة للتسليم');
      expect(kitchenSourceLabel('pos'), 'نقطة البيع');
      expect(kitchenFulfillmentLabel('dine_in'), 'داخل الفرع');
      expect(
        kitchenItemStatusLabel(KitchenItemStatus.pending),
        'بانتظار البدء',
      );
    });
  });

  group('elapsed time', () {
    final placedAt = DateTime.utc(2026, 10, 24, 9);
    final now = DateTime.utc(2026, 10, 24, 9, 5);

    test('missing or future timestamps count as zero', () {
      expect(kitchenElapsedMinutes(null, now), 0);
      expect(kitchenElapsedMinutes(DateTime.utc(2026, 10, 24, 9, 30), now), 0);
      expect(kitchenElapsedLabel(null, now), S.kitchenNow);
      expect(kitchenElapsedLabel(placedAt, placedAt), S.kitchenNow);
    });

    test('the age is shown in minutes then hours', () {
      expect(kitchenElapsedMinutes(placedAt, now), 5);
      expect(kitchenElapsedLabel(placedAt, now), '5m');

      final later = placedAt.add(const Duration(hours: 1, minutes: 15));
      expect(kitchenElapsedLabel(placedAt, later), '1h 15m');

      final wholeHour = placedAt.add(const Duration(hours: 2));
      expect(kitchenElapsedLabel(placedAt, wholeHour), '2h');
    });

    test('a ticket is late from fifteen minutes onward', () {
      expect(kitchenIsLate(placedAt, now), isFalse);
      expect(
        kitchenIsLate(placedAt, placedAt.add(const Duration(minutes: 14))),
        isFalse,
      );
      expect(
        kitchenIsLate(placedAt, placedAt.add(const Duration(minutes: 15))),
        isTrue,
      );
      expect(kitchenIsLate(null, now), isFalse);
    });

    test('the age is localised', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);

      expect(kitchenElapsedLabel(placedAt, now), '٥ د');
      expect(
        kitchenElapsedLabel(
          placedAt,
          placedAt.add(const Duration(hours: 1, minutes: 15)),
        ),
        '١ س ١٥ د',
      );
    });

    test('the handoff label is empty until the ticket is completed', () {
      expect(kitchenHandedOffLabel(null), isEmpty);
      expect(
        kitchenHandedOffLabel(DateTime(2026, 10, 24, 9, 5)),
        startsWith('Handed off '),
      );

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(
        kitchenHandedOffLabel(DateTime(2026, 10, 24, 9, 5)),
        startsWith('سُلّم '),
      );
    });
  });

  group('item options', () {
    const large = AdminKitchenOption(nameAr: 'كبير', nameEn: 'Large');
    const oat = AdminKitchenOption(nameAr: 'شوفان', nameEn: 'Oat milk');

    test('the group name is followed by the chosen options', () {
      final item = _item(
        optionGroupAr: 'الحجم',
        optionGroupEn: 'Size',
        options: const <AdminKitchenOption>[large, oat],
      );

      expect(kitchenItemOptions(item), 'Size · Large · Oat milk');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(kitchenItemOptions(item), 'الحجم · كبير · شوفان');
    });

    test('an item without options shows nothing', () {
      expect(kitchenItemOptions(_item()), isEmpty);
      expect(kitchenItemOptions(_item(optionGroupEn: 'Size')), isEmpty);
    });

    test('a missing group name still shows the options', () {
      final item = _item(options: const <AdminKitchenOption>[large]);

      expect(kitchenItemOptions(item), 'Large');
    });

    test('the group name falls back to the other language', () {
      final item = _item(
        optionGroupAr: 'الحجم',
        options: const <AdminKitchenOption>[large],
      );

      expect(kitchenItemOptions(item), 'الحجم · Large');
    });
  });

  group('mutation messages', () {
    test('each failure explains itself', () {
      expect(
        kitchenMutationErrorMessage(KitchenMutationOutcome.permissionDenied),
        S.kitchenPermissionDenied,
      );
      expect(
        kitchenMutationErrorMessage(KitchenMutationOutcome.notFound),
        S.kitchenTicketNotFoundMessage,
      );
      expect(
        kitchenMutationErrorMessage(KitchenMutationOutcome.invalidStatus),
        S.kitchenInvalidTransitionMessage,
      );
      expect(
        kitchenMutationErrorMessage(KitchenMutationOutcome.invalidTransition),
        S.kitchenInvalidTransitionMessage,
      );
      expect(
        kitchenMutationErrorMessage(KitchenMutationOutcome.failed),
        S.kitchenActionFailed,
      );
    });
  });
}
