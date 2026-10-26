import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/models/subscription_filter.dart';

AdminSubscription _subscription({
  required String id,
  String status = 'active',
  String? name = 'Sara Ali',
  String? email = 'sara@example.com',
  String? phone = '0550000000',
  String? planAr = 'الخطة الذهبية',
  String? planEn = 'Gold plan',
  String? code = 'gold',
  String? reference,
  DateTime? endsAt,
}) => AdminSubscription(
  id: id,
  status: status,
  customerName: name,
  customerEmail: email,
  customerPhone: phone,
  planNameAr: planAr,
  planNameEn: planEn,
  planCode: code,
  paymentReference: reference,
  endsAt: endsAt,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('filterSubscriptions', () {
    final soon = DateTime.now().add(const Duration(days: 2));
    final subscriptions = <AdminSubscription>[
      _subscription(id: 's1', endsAt: soon),
      _subscription(
        id: 's2',
        name: 'Omar Hassan',
        email: 'omar@shop.com',
        phone: '0551234567',
        planAr: null,
        planEn: 'Silver plan',
        code: 'silver',
      ),
      _subscription(
        id: 's3',
        status: 'pending_payment',
        name: 'Mona Adel',
        planAr: null,
        planEn: null,
        code: null,
        endsAt: null,
      ),
      _subscription(
        id: 's4',
        status: 'expired',
        name: 'Khaled',
        planAr: null,
        planEn: null,
        code: null,
      ),
      _subscription(
        id: 's5',
        status: 'cancelled',
        name: 'Nour',
        planAr: null,
        planEn: null,
        code: null,
        reference: 'pay_555',
      ),
    ];

    test('returns everyone for the default filter and empty search', () {
      expect(filterSubscriptions(subscriptions), subscriptions);
    });

    test('matches customer, plan and payment reference without case', () {
      expect(
        filterSubscriptions(subscriptions, search: ' OMAR ').map((s) => s.id),
        ['s2'],
      );
      expect(
        filterSubscriptions(subscriptions, search: 'gold').map((s) => s.id),
        ['s1'],
      );
      expect(
        filterSubscriptions(subscriptions, search: 'pay_555').map((s) => s.id),
        ['s5'],
      );
      expect(
        filterSubscriptions(
          subscriptions,
          search: '0551234567',
        ).map((s) => s.id),
        ['s2'],
      );
    });

    test('applies the directory filters to the effective status', () {
      expect(
        filterSubscriptions(
          subscriptions,
          filter: SubscriptionFilter.active,
        ).map((s) => s.id),
        ['s1', 's2'],
      );
      expect(
        filterSubscriptions(
          subscriptions,
          filter: SubscriptionFilter.expiringSoon,
        ).map((s) => s.id),
        ['s1'],
      );
      expect(
        filterSubscriptions(
          subscriptions,
          filter: SubscriptionFilter.pendingPayment,
        ).map((s) => s.id),
        ['s3'],
      );
      expect(
        filterSubscriptions(
          subscriptions,
          filter: SubscriptionFilter.expired,
        ).map((s) => s.id),
        ['s4'],
      );
      expect(
        filterSubscriptions(
          subscriptions,
          filter: SubscriptionFilter.cancelled,
        ).map((s) => s.id),
        ['s5'],
      );
    });

    test('combines a filter with the search query', () {
      expect(
        filterSubscriptions(
          subscriptions,
          search: 'omar',
          filter: SubscriptionFilter.active,
        ).map((s) => s.id),
        ['s2'],
      );
      expect(
        filterSubscriptions(
          subscriptions,
          search: 'omar',
          filter: SubscriptionFilter.pendingPayment,
        ),
        isEmpty,
      );
    });
  });

  test('every filter has its own label', () {
    final labels = SubscriptionFilter.values
        .map((filter) => filter.label)
        .toSet();

    expect(labels, hasLength(SubscriptionFilter.values.length));
    expect(SubscriptionFilter.all.label, S.subscriptionsFilterAll);
  });
}
