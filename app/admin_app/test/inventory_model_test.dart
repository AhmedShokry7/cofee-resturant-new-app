import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_filters.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_material_option.dart';
import 'package:admin_app/features/inventory/data/models/admin_inventory_metrics.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_draft.dart';
import 'package:admin_app/features/inventory/data/models/admin_stock_movement_metrics.dart';

void main() {
  group('AdminInventoryItem', () {
    test('a full directory row maps every field', () {
      final item = AdminInventoryItem.fromJson(<String, dynamic>{
        'id': 'm1',
        'sku': 'BEAN-ARABICA',
        'name_ar': 'حبوب أرابيكا',
        'name_en': 'Arabica beans',
        'category': 'حبوب البن',
        'unit': 'kg',
        'unit_cost': 420.5,
        'reorder_level': 10,
        'quantity_on_hand': 4.5,
        'stock_value': 1892.25,
        'status': 'low',
        'notes': 'يُحفظ بعيدًا عن الرطوبة',
        'last_movement_at': '2026-10-24T09:15:00Z',
        'stock_updated_at': '2026-10-24T09:15:00Z',
        'created_at': '2026-10-01T08:00:00Z',
        'updated_at': '2026-10-20T12:00:00Z',
      });

      expect(item.id, 'm1');
      expect(item.sku, 'BEAN-ARABICA');
      expect(item.category, 'حبوب البن');
      expect(item.unit, 'kg');
      expect(item.unitCost, 420.5);
      expect(item.reorderLevel, 10);
      expect(item.quantityOnHand, 4.5);
      expect(item.stockValue, 1892.25);
      expect(item.isLow, isTrue);
      expect(item.isOut, isFalse);
      expect(item.isOk, isFalse);
      expect(item.notes, 'يُحفظ بعيدًا عن الرطوبة');
      expect(item.nameFor(AppLanguage.arabic), 'حبوب أرابيكا');
      expect(item.nameFor(AppLanguage.english), 'Arabica beans');
      expect(item.lastMovementAt?.toUtc(), DateTime.utc(2026, 10, 24, 9, 15));
      expect(item.stockUpdatedAt?.toUtc(), DateTime.utc(2026, 10, 24, 9, 15));
      expect(item.createdAt?.toUtc(), DateTime.utc(2026, 10, 1, 8));
      expect(item.updatedAt?.toUtc(), DateTime.utc(2026, 10, 20, 12));
    });

    test('a missing row falls back to safe defaults', () {
      final item = AdminInventoryItem.fromJson(const <String, dynamic>{});
      expect(item.id, '');
      expect(item.nameAr, '');
      expect(item.sku, isNull);
      expect(item.nameEn, isNull);
      expect(item.unit, 'piece');
      expect(item.unitCost, 0);
      expect(item.quantityOnHand, 0);
      expect(item.status, 'out');
      expect(item.isOut, isTrue);
      expect(item.isOk, isFalse);
      expect(item.lastMovementAt, isNull);
      expect(item.nameFor(AppLanguage.english), '');
    });

    test('a preferred language falls back to the other one', () {
      final item = AdminInventoryItem.fromJson(const <String, dynamic>{
        'id': 'm2',
        'name_ar': 'حليب كامل الدسم',
        'name_en': '   ',
      });
      expect(item.nameFor(AppLanguage.english), 'حليب كامل الدسم');
    });

    test('a page keeps the total and drops malformed rows', () {
      final page = AdminInventoryPage.fromJson(<String, dynamic>{
        'total': '12',
        'rows': <Object>[
          <String, dynamic>{'id': 'm1', 'name_ar': 'بن'},
          'not a row',
        ],
      });
      expect(page.total, 12);
      expect(page.rows, hasLength(1));
      expect(page.rows.single.id, 'm1');
    });
  });

  group('AdminInventoryMetrics', () {
    test('maps the counters and the latest movement', () {
      final metrics = AdminInventoryMetrics.fromJson(<String, dynamic>{
        'total': 18,
        'low': 3,
        'out': 2,
        'stock_value': 12500.75,
        'categories': 6,
        'branches': 2,
        'latest_movement_at': '2026-10-24T18:00:00Z',
      });
      expect(metrics.total, 18);
      expect(metrics.low, 3);
      expect(metrics.out, 2);
      expect(metrics.stockValue, 12500.75);
      expect(metrics.categories, 6);
      expect(metrics.branches, 2);
      expect(metrics.latestMovementAt?.toUtc(), DateTime.utc(2026, 10, 24, 18));
      expect(AdminInventoryMetrics.empty.total, 0);
    });
  });

  group('AdminInventoryFilters', () {
    test('maps branches and category counts', () {
      final filters = AdminInventoryFilters.fromJson(<String, dynamic>{
        'branches': <Object>[
          <String, dynamic>{
            'id': 'b1',
            'code': 'MAADI',
            'name_ar': 'المعادي',
            'name_en': 'Maadi',
            'is_active': true,
          },
          <String, dynamic>{
            'id': 'b2',
            'code': 'NASR',
            'name_ar': 'مدينة نصر',
            'name_en': 'Nasr City',
            'is_active': false,
          },
        ],
        'categories': <Object>[
          <String, dynamic>{'value': 'حبوب البن', 'count': 4},
          <String, dynamic>{'value': 'ألبان', 'count': 3},
        ],
      });

      expect(filters.hasBranches, isTrue);
      expect(filters.branches, hasLength(2));
      expect(filters.branches.first.isActive, isTrue);
      expect(filters.branches.last.isActive, isFalse);
      expect(filters.branches.last.nameFor(AppLanguage.english), 'Nasr City');
      expect(filters.branches.first.nameFor(AppLanguage.arabic), 'المعادي');
      expect(filters.branchById('b2')?.code, 'NASR');
      expect(filters.branchById(null), isNull);
      expect(filters.branchById('missing'), isNull);
      expect(filters.hasCategories, isTrue);
      expect(filters.categories.first.value, 'حبوب البن');
      expect(filters.categories.first.count, 4);
    });

    test('an empty payload stays empty', () {
      final filters = AdminInventoryFilters.fromJson(const <String, dynamic>{});
      expect(filters.hasBranches, isFalse);
      expect(filters.hasCategories, isFalse);
      expect(filters.categories, isEmpty);
    });
  });

  group('AdminInventoryMaterialOption', () {
    test('maps the material and its branch balance', () {
      final option = AdminInventoryMaterialOption.fromJson(<String, dynamic>{
        'id': 'm1',
        'sku': 'MILK-1',
        'name_ar': 'حليب',
        'name_en': 'Milk',
        'unit': 'l',
        'unit_cost': 35,
        'reorder_level': 12,
        'quantity_on_hand': 8,
      });
      expect(option.id, 'm1');
      expect(option.sku, 'MILK-1');
      expect(option.unit, 'l');
      expect(option.unitCost, 35);
      expect(option.reorderLevel, 12);
      expect(option.quantityOnHand, 8);
      expect(option.nameFor(AppLanguage.english), 'Milk');
    });

    test('a missing English name falls back to Arabic', () {
      final option = AdminInventoryMaterialOption.fromJson(
        const <String, dynamic>{'id': 'm1', 'name_ar': 'سكر'},
      );
      expect(option.nameFor(AppLanguage.english), 'سكر');
      expect(option.unit, 'piece');
    });
  });

  group('AdminStockMovement', () {
    test('a full ledger row maps the movement, material, branch and actor', () {
      final movement = AdminStockMovement.fromJson(<String, dynamic>{
        'id': 7,
        'created_at': '2026-10-24T09:15:00Z',
        'movement_type': 'issue',
        'quantity_delta': -2.5,
        'balance_after': 7.5,
        'unit_cost': 12.25,
        'movement_value': 30.63,
        'reference': 'INV-1042',
        'note': 'صرف لتشغيل الفرع',
        'material_id': 'm1',
        'material_sku': 'BEAN-ARABICA',
        'material_name_ar': 'حبوب أرابيكا',
        'material_name_en': 'Arabica beans',
        'unit': 'kg',
        'branch_id': 'b1',
        'branch_code': 'MAADI',
        'branch_name_ar': 'المعادي',
        'branch_name_en': 'Maadi',
        'actor_name': 'Mona Ali',
        'actor_email': 'mona@example.com',
      });

      expect(movement.id, 7);
      expect(movement.movementType, InventoryMovementType.issue);
      expect(movement.isInbound, isFalse);
      expect(movement.quantityDelta, -2.5);
      expect(movement.balanceAfter, 7.5);
      expect(movement.unitCost, 12.25);
      expect(movement.movementValue, 30.63);
      expect(movement.reference, 'INV-1042');
      expect(movement.note, 'صرف لتشغيل الفرع');
      expect(movement.unit, 'kg');
      expect(movement.materialNameFor(AppLanguage.english), 'Arabica beans');
      expect(movement.materialNameFor(AppLanguage.arabic), 'حبوب أرابيكا');
      expect(movement.branchNameFor(AppLanguage.english), 'Maadi');
      expect(movement.branchNameFor(AppLanguage.arabic), 'المعادي');
      expect(movement.actorName, 'Mona Ali');
      expect(movement.actorEmail, 'mona@example.com');
      expect(movement.createdAt?.toUtc(), DateTime.utc(2026, 10, 24, 9, 15));
    });

    test('a receipt is inbound and falls back to Arabic names', () {
      final movement = AdminStockMovement.fromJson(<String, dynamic>{
        'id': 8,
        'movement_type': 'receipt',
        'quantity_delta': 5,
        'material_name_ar': 'سكر',
        'branch_name_ar': 'المعادي',
        'unit': 'kg',
      });
      expect(movement.movementType, InventoryMovementType.receipt);
      expect(movement.isInbound, isTrue);
      expect(movement.materialNameFor(AppLanguage.english), 'سكر');
      expect(movement.branchNameFor(AppLanguage.english), 'المعادي');
    });

    test('unknown types and malformed values stay safe', () {
      final movement = AdminStockMovement.fromJson(const <String, dynamic>{
        'id': 'bad',
        'movement_type': 'transfer',
        'quantity_delta': 'oops',
      });
      expect(movement.id, 0);
      expect(movement.movementType, isNull);
      expect(movement.quantityDelta, 0);
      expect(movement.unit, 'piece');
      expect(
        InventoryMovementType.fromValue('waste'),
        InventoryMovementType.waste,
      );
      expect(InventoryMovementType.fromValue(null), isNull);
    });

    test('a page keeps the total and drops malformed rows', () {
      final page = AdminStockMovementPage.fromJson(<String, dynamic>{
        'total': 3,
        'rows': <Object?>[
          <String, dynamic>{'id': 1},
          null,
        ],
      });
      expect(page.total, 3);
      expect(page.rows, hasLength(1));
      expect(page.rows.single.id, 1);
    });
  });

  group('AdminStockMovementMetrics', () {
    test('maps the activity counters and values', () {
      final metrics = AdminStockMovementMetrics.fromJson(<String, dynamic>{
        'total': 22,
        'receipts': 9,
        'issues': 8,
        'waste': 3,
        'counts': 2,
        'received_value': 5400.25,
        'issued_value': 3100,
        'waste_value': 220.5,
        'actors': 4,
        'latest_at': '2026-10-24T18:30:00Z',
      });
      expect(metrics.total, 22);
      expect(metrics.receipts, 9);
      expect(metrics.issues, 8);
      expect(metrics.waste, 3);
      expect(metrics.counts, 2);
      expect(metrics.receivedValue, 5400.25);
      expect(metrics.issuedValue, 3100);
      expect(metrics.wasteValue, 220.5);
      expect(metrics.actors, 4);
      expect(metrics.latestAt?.toUtc(), DateTime.utc(2026, 10, 24, 18, 30));
      expect(AdminStockMovementMetrics.empty.total, 0);
    });
  });

  group('drafts', () {
    test('a material draft sends every editable field', () {
      final draft = AdminInventoryDraft(
        id: 'm1',
        sku: 'BEAN-1',
        nameAr: 'بن',
        nameEn: 'Beans',
        category: 'حبوب البن',
        unit: 'kg',
        unitCost: 420,
        reorderLevel: 10,
        notes: 'ملاحظة',
      );
      expect(draft.toJson(), <String, dynamic>{
        'id': 'm1',
        'sku': 'BEAN-1',
        'name_ar': 'بن',
        'name_en': 'Beans',
        'category': 'حبوب البن',
        'unit': 'kg',
        'unit_cost': 420.0,
        'reorder_level': 10.0,
        'notes': 'ملاحظة',
      });
    });

    test('a new material draft omits the id', () {
      const draft = AdminInventoryDraft(nameAr: 'بن');
      expect(draft.toJson().containsKey('id'), isFalse);
    });

    test('a movement draft includes the cost only when entered', () {
      final withoutCost = AdminStockMovementDraft(
        materialId: 'm1',
        branchId: 'b1',
        type: InventoryMovementType.receipt,
        quantity: 5,
        reference: 'INV-1',
      );
      expect(withoutCost.toJson(), <String, dynamic>{
        'material_id': 'm1',
        'branch_id': 'b1',
        'type': 'receipt',
        'quantity': 5.0,
        'reference': 'INV-1',
        'note': null,
      });

      final withCost = AdminStockMovementDraft(
        materialId: 'm1',
        branchId: 'b1',
        type: InventoryMovementType.count,
        quantity: 8,
        unitCost: 12.5,
        note: 'جرد أسبوعي',
      );
      expect(withCost.toJson()['unit_cost'], 12.5);
      expect(withCost.toJson()['type'], 'count');
      expect(withCost.toJson()['note'], 'جرد أسبوعي');
    });
  });
}
