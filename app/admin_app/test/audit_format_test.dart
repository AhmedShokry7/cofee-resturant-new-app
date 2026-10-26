import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_format.dart';

AdminAuditLog _log({
  int id = 1,
  String action = 'core.branch.update',
  String entityType = 'branch',
  String? actorUserId = 'u1',
  String? actorName = 'Mona Ali',
  String? actorEmail,
  List<String> rolesAr = const <String>[],
  List<String> rolesEn = const <String>[],
  Map<String, dynamic>? oldValues,
  Map<String, dynamic>? newValues,
}) => AdminAuditLog(
  id: id,
  action: action,
  entityType: entityType,
  actorUserId: actorUserId,
  actorName: actorName,
  actorEmail: actorEmail,
  actorRolesAr: rolesAr,
  actorRolesEn: rolesEn,
  oldValues: oldValues,
  newValues: newValues,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  test('known actions, domains and entities get human labels', () {
    expect(auditActionLabel('core.branch.update'), S.auditActionBranchUpdate);
    expect(
      auditActionLabel('marketing.coupon.create'),
      S.auditActionCouponCreate,
    );
    expect(auditActionLabel('order.status.update'), S.auditActionOrderStatus);
    expect(auditActionLabel('unknown.thing'), S.auditUnknownAction);
    expect(
      auditActionLabel('kitchen.ticket.update'),
      S.auditActionKitchenTicketUpdate,
    );
    expect(
      auditActionLabel('kitchen.item.update'),
      S.auditActionKitchenItemUpdate,
    );

    expect(auditDomainKey(_log(action: 'orders.order.update')), 'order');
    expect(auditDomainKey(_log(action: 'inventory.stock.adjust')), 'stock');
    expect(auditDomainKey(_log(action: 'permissions.grant')), 'identity');
    expect(auditDomainKey(_log(action: 'kitchen.ticket.update')), 'kitchen');
    expect(auditDomainLabel('order'), S.auditDomainOrders);
    expect(auditDomainLabel('stock'), S.auditDomainInventory);
    expect(auditDomainLabel('identity'), S.auditDomainSecurity);
    expect(auditDomainLabel('kitchen'), S.auditDomainKitchen);
    expect(auditDomainLabel('nope'), S.auditDomainOther);

    expect(auditEntityLabel('branch'), S.auditEntityBranch);
    expect(auditEntityLabel('product_review'), S.auditEntityReview);
    expect(auditEntityLabel('kitchen_ticket'), S.auditEntityKitchenTicket);
    expect(auditEntityLabel('something'), S.auditEntityOther);
  });

  test('the actor falls back from name to email to system', () {
    expect(auditActorName(_log()), 'Mona Ali');
    expect(
      auditActorName(_log(actorName: null, actorEmail: 'mona@example.com')),
      'mona@example.com',
    );
    expect(
      auditActorName(_log(actorName: null, actorUserId: 'u1')),
      S.auditUnknownActor,
    );
    expect(
      auditActorName(_log(actorName: null, actorUserId: null)),
      S.auditSystemActor,
    );
    expect(auditActorInitial(_log()), 'M');
    expect(auditActorInitial(_log(actorUserId: null, actorName: null)), '—');
  });

  test('the actor roles follow the active language', () {
    final log = _log(rolesAr: ['مدير فرع'], rolesEn: ['Branch manager']);

    expect(auditActorRole(log), 'Branch manager');

    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(auditActorRole(log), 'مدير فرع');

    AppLocale.instance.debugSet(AppLanguage.english);
    expect(auditActorRole(_log()), S.auditStaffRole);
    expect(
      auditActorRole(_log(actorUserId: null, actorName: null)),
      S.auditSystemActor,
    );
  });

  test('the subject prefers the localized human name of the row', () {
    final log = _log(
      oldValues: {'name_ar': 'الفرع القديم', 'name_en': 'Old branch'},
      newValues: {'name_ar': 'الفرع الجديد', 'name_en': 'New branch'},
    );

    expect(auditSubject(log), 'New branch');
    expect(auditEventTitle(log), '${S.auditActionBranchUpdate} • New branch');

    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(auditSubject(log), 'الفرع الجديد');

    expect(auditSubject(_log()), isNull);
    expect(auditEventTitle(_log()), S.auditActionBranchUpdate);
  });

  test('only real changes survive, without audit bookkeeping fields', () {
    final changes = auditChanges(
      _log(
        oldValues: {
          'id': 'br-1',
          'created_at': '2026-01-01',
          'is_active': true,
          'name_ar': 'قديم',
          'latitude': 30.1,
        },
        newValues: {
          'id': 'br-1',
          'created_at': '2026-01-02',
          'is_active': true,
          'name_ar': 'جديد',
          'latitude': 30.1,
        },
      ),
    );

    expect(changes.map((change) => change.key), ['name_ar']);
    expect(changes.single.before, 'قديم');
    expect(changes.single.after, 'جديد');
    expect(
      auditChanges(_log(oldValues: {'x': 1}, newValues: {'x': 1})),
      isEmpty,
    );
  });

  test('field keys become readable labels', () {
    expect(auditFieldLabel('name_ar'), S.auditFieldNameAr);
    expect(auditFieldLabel('product_ids'), S.auditFieldProducts);
    expect(auditFieldLabel('points_cost'), S.auditFieldPointsCost);
    expect(auditFieldLabel('usage_limit'), S.auditFieldUsageLimit);
    expect(auditFieldLabel('item_id'), S.auditFieldItem);
    expect(auditFieldLabel('some_new_field'), 'some new field');
  });

  test('recorded values are localized for the client', () {
    expect(auditValueLabel('has_image', true), S.auditValueHasImage);
    expect(auditValueLabel('has_image', false), S.auditValueNoImage);
    expect(auditValueLabel('is_active', true), S.activeStatus);
    expect(auditValueLabel('is_active', false), S.inactiveStatus);
    expect(auditValueLabel('is_published', true), S.published);
    expect(auditValueLabel('is_published', false), S.reviewsHidden);
    expect(auditValueLabel('queued', true), S.auditValueQueued);
    expect(auditValueLabel('applies_to', 'all'), S.auditValueAppliesAll);
    expect(
      auditValueLabel('applies_to', 'product'),
      S.auditValueAppliesProduct,
    );
    expect(
      auditValueLabel('discount_type', 'percentage'),
      S.auditValueDiscountPercentage,
    );
    expect(
      auditValueLabel('audience', 'push_enabled'),
      S.auditValueAudiencePush,
    );
    expect(auditValueLabel('reason', 'restock'), S.auditValueStockRestock);
    expect(auditValueLabel('type', 'promo'), S.auditValueTypePromo);
    expect(auditValueLabel('status', 'completed'), S.statusCompleted);
    expect(auditValueLabel('role', 'branch_manager'), S.roleBranchManager);
    expect(auditValueLabel('product_ids', [1, 2, 3]), S.auditSelectedCount(3));
    expect(auditValueLabel('product_ids', const []), S.auditValueEmptyList);
    expect(auditValueLabel('name_ar', null), S.auditDetailsNoValue);
    expect(auditValueLabel('opens_at', '09:30:00'), '9:30 AM');
  });

  test('day labels group today and yesterday in the client language', () {
    expect(auditDayLabel(null), '—');
    expect(auditDayLabel(DateTime.now()), S.today);
    expect(
      auditDayLabel(DateTime.now().subtract(const Duration(days: 1))),
      S.yesterday,
    );
  });
}
