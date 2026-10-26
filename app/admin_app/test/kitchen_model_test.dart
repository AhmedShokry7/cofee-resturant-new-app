import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('statuses', () {
    test(
      'ticket statuses parse case-insensitively and fall back to queued',
      () {
        expect(
          KitchenTicketStatus.fromValue(' PREPARING '),
          KitchenTicketStatus.preparing,
        );
        expect(
          KitchenTicketStatus.fromValue('ready'),
          KitchenTicketStatus.ready,
        );
        expect(
          KitchenTicketStatus.fromValue('completed'),
          KitchenTicketStatus.completed,
        );
        expect(
          KitchenTicketStatus.fromValue('cancelled'),
          KitchenTicketStatus.cancelled,
        );
        expect(
          KitchenTicketStatus.fromValue('anything'),
          KitchenTicketStatus.queued,
        );
        expect(KitchenTicketStatus.fromValue(null), KitchenTicketStatus.queued);
      },
    );

    test('only queued, preparing and ready are active', () {
      expect(KitchenTicketStatus.queued.isActive, isTrue);
      expect(KitchenTicketStatus.preparing.isActive, isTrue);
      expect(KitchenTicketStatus.ready.isActive, isTrue);
      expect(KitchenTicketStatus.completed.isActive, isFalse);
      expect(KitchenTicketStatus.cancelled.isActive, isFalse);
    });

    test('item statuses fall back to pending', () {
      expect(KitchenItemStatus.fromValue('ready'), KitchenItemStatus.ready);
      expect(
        KitchenItemStatus.fromValue('PREPARING'),
        KitchenItemStatus.preparing,
      );
      expect(KitchenItemStatus.fromValue(''), KitchenItemStatus.pending);
      expect(KitchenItemStatus.fromValue(null), KitchenItemStatus.pending);
    });
  });

  group('option and item', () {
    test('option names follow the language and fall back to the other one', () {
      const option = AdminKitchenOption(nameAr: 'كبير', nameEn: 'Large');

      expect(option.nameFor(AppLanguage.english), 'Large');
      expect(option.nameFor(AppLanguage.arabic), 'كبير');

      const arabicOnly = AdminKitchenOption(nameAr: 'كبير', nameEn: ' ');
      expect(arabicOnly.nameFor(AppLanguage.english), 'كبير');
    });

    test('an item parses quantities, options and notes', () {
      final item = AdminKitchenTicketItem.fromJson({
        'id': 'i1',
        'status': 'ready',
        'quantity': '2',
        'product_name_ar': 'فلات وايت',
        'product_name_en': 'Flat white',
        'note': '  بدون سكر  ',
        'option_group_name_ar': 'الحجم',
        'option_group_name_en': 'Size',
        'options': [
          {'name_ar': 'كبير', 'name_en': 'Large'},
          {'name_ar': 'حليب شوفان', 'name_en': 'Oat milk'},
        ],
      });

      expect(item.id, 'i1');
      expect(item.status, KitchenItemStatus.ready);
      expect(item.isReady, isTrue);
      expect(item.quantity, 2);
      expect(item.note, 'بدون سكر');
      expect(item.nameFor(AppLanguage.english), 'Flat white');
      expect(item.nameFor(AppLanguage.arabic), 'فلات وايت');
      expect(item.optionsFor(AppLanguage.english), 'Large · Oat milk');
      expect(item.optionsFor(AppLanguage.arabic), 'كبير · حليب شوفان');
    });

    test('an item without a name falls back and defaults safely', () {
      final item = AdminKitchenTicketItem.fromJson({
        'id': 'i2',
        'product_name_ar': 'موكا',
        'product_name_en': '',
        'quantity': 'nope',
      });

      expect(item.status, KitchenItemStatus.pending);
      expect(item.quantity, 1);
      expect(item.nameFor(AppLanguage.english), 'موكا');
      expect(item.optionsFor(AppLanguage.english), isEmpty);
    });
  });

  group('ticket', () {
    test('a ticket parses every field the card shows', () {
      final ticket = AdminKitchenTicket.fromJson({
        'id': 't1',
        'status': 'preparing',
        'placed_at': '2026-10-24T09:00:00Z',
        'started_at': '2026-10-24T09:02:00Z',
        'order_id': 'o1',
        'order_number': '#1042',
        'order_status': 'preparing',
        'fulfillment_type': 'dine_in',
        'order_source': 'pos',
        'table_number': ' 7 ',
        'customer_note': '  بدون سكر  ',
        'customer_name': '  Mona Ali  ',
        'branch_id': 'b1',
        'branch_code': 'MAADI',
        'branch_name_ar': 'المعادي',
        'branch_name_en': 'Maadi',
        'item_count': 2,
        'ready_count': 1,
        'items': [
          {
            'id': 'i1',
            'product_name_ar': 'فلات وايت',
            'product_name_en': 'Flat white',
          },
        ],
      });

      expect(ticket.id, 't1');
      expect(ticket.status, KitchenTicketStatus.preparing);
      expect(ticket.placedAt, DateTime.utc(2026, 10, 24, 9));
      expect(ticket.startedAt, DateTime.utc(2026, 10, 24, 9, 2));
      expect(ticket.orderId, 'o1');
      expect(ticket.orderNumber, '#1042');
      expect(ticket.isQueued, isFalse);
      expect(ticket.isPreparing, isTrue);
      expect(ticket.isActive, isTrue);
      expect(ticket.isPos, isTrue);
      expect(ticket.isDineIn, isTrue);
      expect(ticket.tableNumber, '7');
      expect(ticket.hasCustomerNote, isTrue);
      expect(ticket.customerNote, 'بدون سكر');
      expect(ticket.hasCustomerName, isTrue);
      expect(ticket.customerName, 'Mona Ali');
      expect(ticket.branchNameFor(AppLanguage.english), 'Maadi');
      expect(ticket.branchNameFor(AppLanguage.arabic), 'المعادي');
      expect(ticket.itemCount, 2);
      expect(ticket.readyCount, 1);
      expect(ticket.items, hasLength(1));
    });

    test('a sparse ticket defaults to an online pickup without a table', () {
      final ticket = AdminKitchenTicket.fromJson({
        'id': 't2',
        'table_number': '   ',
        'items': 'not a list',
      });

      expect(ticket.status, KitchenTicketStatus.queued);
      expect(ticket.placedAt, isNull);
      expect(ticket.tableNumber, isNull);
      expect(ticket.fulfillmentType, 'pickup');
      expect(ticket.orderSource, 'online');
      expect(ticket.isPos, isFalse);
      expect(ticket.isDineIn, isFalse);
      expect(ticket.hasCustomerNote, isFalse);
      expect(ticket.hasCustomerName, isFalse);
      expect(ticket.items, isEmpty);
      expect(ticket.branchNameFor(AppLanguage.english), isEmpty);
    });

    test('the branch name falls back to the Arabic one', () {
      final ticket = AdminKitchenTicket.fromJson({
        'branch_name_ar': 'المعادي',
        'branch_name_en': '',
      });

      expect(ticket.branchNameFor(AppLanguage.english), 'المعادي');
    });
  });

  group('board, metrics and filters', () {
    test('the board parses its rows and total', () {
      final board = AdminKitchenBoard.fromJson({
        'rows': [
          {'id': 't1', 'order_number': '#1'},
          'skip me',
          {'id': 't2', 'order_number': '#2'},
        ],
        'total': '12',
      });

      expect(board.tickets, hasLength(2));
      expect(board.tickets.first.id, 't1');
      expect(board.total, 12);
    });

    test('the board tolerates a missing rows payload', () {
      final board = AdminKitchenBoard.fromJson({'rows': null, 'total': null});

      expect(board.tickets, isEmpty);
      expect(board.total, 0);
    });

    test('metrics parse numbers, strings and empty payloads', () {
      final metrics = AdminKitchenMetrics.fromJson({
        'queued': 3,
        'preparing': '2',
        'ready': 1,
        'active': 6,
        'completed_today': '9',
        'late': 1,
        'oldest_wait_minutes': '21',
        'avg_prep_minutes': '7.5',
      });

      expect(metrics.queued, 3);
      expect(metrics.preparing, 2);
      expect(metrics.ready, 1);
      expect(metrics.active, 6);
      expect(metrics.completedToday, 9);
      expect(metrics.late, 1);
      expect(metrics.oldestWaitMinutes, 21);
      expect(metrics.avgPrepMinutes, 7.5);
      expect(metrics.hasActiveTickets, isTrue);

      final empty = AdminKitchenMetrics.fromJson(const <String, dynamic>{});
      expect(empty.queued, 0);
      expect(empty.avgPrepMinutes, 0);
      expect(empty.hasActiveTickets, isFalse);
    });

    test('filters parse their branch options', () {
      final filters = AdminKitchenFilters.fromJson({
        'branches': [
          {
            'id': 'b1',
            'code': 'MAADI',
            'name_ar': 'المعادي',
            'name_en': 'Maadi',
            'is_active': false,
          },
          'skip me',
        ],
      });

      expect(filters.hasBranches, isTrue);
      expect(filters.branches.single.code, 'MAADI');
      expect(filters.branches.single.isActive, isFalse);
      expect(filters.branchById('b1')?.nameFor(AppLanguage.english), 'Maadi');
      expect(filters.branchById('nope'), isNull);
      expect(filters.branchById(null), isNull);

      final empty = AdminKitchenFilters.fromJson(const <String, dynamic>{});
      expect(empty.hasBranches, isFalse);
      expect(empty.branchById('b1'), isNull);
    });

    test('a branch without an English name falls back to Arabic', () {
      final branch = AdminKitchenBranchOption.fromJson({
        'id': 'b1',
        'name_ar': 'المعادي',
        'name_en': '',
      });

      expect(branch.nameFor(AppLanguage.english), 'المعادي');
      expect(branch.isActive, isTrue);
    });
  });
}
