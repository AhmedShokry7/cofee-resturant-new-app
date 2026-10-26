import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  test('an audit row parses the actor, roles and payloads', () {
    final log = AdminAuditLog.fromJson({
      'id': 42,
      'actor_user_id': 'u1',
      'actor_name': 'Mona Ali',
      'actor_email': 'mona@example.com',
      'actor_role': 'manager',
      'actor_roles_ar': ['مدير فرع'],
      'actor_roles_en': ['Branch manager'],
      'action': 'core.branch.update',
      'domain': 'core',
      'is_critical': true,
      'entity_type': 'branch',
      'entity_id': 'br-1',
      'branch_id': 'b1',
      'branch_name_ar': 'فرع المعادي',
      'branch_name_en': 'Maadi branch',
      'old_values': {'name_ar': 'قديم'},
      'new_values': {'name_ar': 'جديد'},
      'created_at': '2026-10-24T09:15:00Z',
    });

    expect(log.id, 42);
    expect(log.actorName, 'Mona Ali');
    expect(log.actorRolesEn, ['Branch manager']);
    expect(log.actorRolesFor(AppLanguage.english), ['Branch manager']);
    expect(log.actorRolesFor(AppLanguage.arabic), ['مدير فرع']);
    expect(log.isCritical, isTrue);
    expect(log.actionDomain, 'core');
    expect(log.branchNameFor(AppLanguage.arabic), 'فرع المعادي');
    expect(log.oldValues?['name_ar'], 'قديم');
    expect(log.createdAt, DateTime.utc(2026, 10, 24, 9, 15));
  });

  test('the domain falls back to the action prefix', () {
    final log = AdminAuditLog.fromJson({
      'id': '7',
      'action': 'marketing.coupon.create',
      'entity_type': 'coupon',
    });

    expect(log.id, 7);
    expect(log.domain, 'marketing');
    expect(log.isCritical, isFalse);
    expect(log.branchNameFor(AppLanguage.english), isEmpty);
  });

  test('the page parses rows and the server total', () {
    final page = AdminAuditPage.fromJson({
      'rows': [
        {'id': 2, 'action': 'order.status.update', 'entity_type': 'order'},
        {'id': 1, 'action': 'stock.adjust', 'entity_type': 'stock'},
      ],
      'total': 25,
    });

    expect(page.rows.map((row) => row.id), [2, 1]);
    expect(page.total, 25);
  });

  test('a malformed page becomes empty instead of throwing', () {
    final page = AdminAuditPage.fromJson({'rows': 'nope'});

    expect(page.rows, isEmpty);
    expect(page.total, 0);
  });

  test('the metrics parse numbers and the last activity date', () {
    final metrics = AdminAuditMetrics.fromJson({
      'total': '40',
      'today': 4,
      'week': 12,
      'critical': 9,
      'critical_week': 2,
      'actors': 5,
      'actors_week': 3,
      'branches': 2,
      'latest_at': '2026-10-24T09:15:00Z',
    });

    expect(metrics.total, 40);
    expect(metrics.today, 4);
    expect(metrics.week, 12);
    expect(metrics.critical, 9);
    expect(metrics.criticalWeek, 2);
    expect(metrics.actors, 5);
    expect(metrics.branches, 2);
    expect(metrics.latestAt, DateTime.utc(2026, 10, 24, 9, 15));
  });
}
