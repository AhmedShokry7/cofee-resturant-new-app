import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/models/customer_filter.dart';

AdminCustomer _customer({
  String id = 'c1',
  String? name = 'Ahmed Shokry',
  String? email = 'ahmed@example.com',
  String? phone = '0500000000',
  int orders = 1,
  bool vip = false,
  bool blacklisted = false,
}) => AdminCustomer(
  id: id,
  fullName: name,
  email: email,
  phone: phone,
  ordersCount: orders,
  isVip: vip,
  isBlacklisted: blacklisted,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('filterCustomers', () {
    final customers = <AdminCustomer>[
      _customer(name: 'Ahmed Shokry', email: 'ahmed@example.com', vip: true),
      _customer(
        id: 'c2',
        name: 'Sara Ali',
        email: 'sara@shop.com',
        phone: '0555555555',
        orders: 0,
      ),
      _customer(
        id: 'c3',
        name: 'Omar',
        email: 'omar@example.com',
        phone: '0551234567',
        blacklisted: true,
        orders: 3,
      ),
    ];

    test('returns everyone for the default filter and empty search', () {
      expect(filterCustomers(customers), customers);
    });

    test('matches a name, an email or a phone without regard to case', () {
      expect(filterCustomers(customers, search: '  AHMED ').map((c) => c.id), [
        'c1',
      ]);
      expect(filterCustomers(customers, search: 'shop.com').map((c) => c.id), [
        'c2',
      ]);
      expect(filterCustomers(customers, search: '0555').map((c) => c.id), [
        'c2',
      ]);
    });

    test('applies the directory filters to real customer flags', () {
      expect(
        filterCustomers(customers, filter: CustomerFilter.vip).map((c) => c.id),
        ['c1'],
      );
      expect(
        filterCustomers(
          customers,
          filter: CustomerFilter.blacklisted,
        ).map((c) => c.id),
        ['c3'],
      );
      expect(
        filterCustomers(
          customers,
          filter: CustomerFilter.buyers,
        ).map((c) => c.id),
        ['c1', 'c3'],
      );
      expect(
        filterCustomers(
          customers,
          filter: CustomerFilter.noOrders,
        ).map((c) => c.id),
        ['c2'],
      );
    });

    test('combines a filter with the search query', () {
      expect(
        filterCustomers(
          customers,
          search: 'omar',
          filter: CustomerFilter.buyers,
        ).map((c) => c.id),
        ['c3'],
      );
      expect(
        filterCustomers(
          customers,
          search: 'omar',
          filter: CustomerFilter.noOrders,
        ),
        isEmpty,
      );
    });
  });

  test('every filter has its own label', () {
    final labels = CustomerFilter.values.map((filter) => filter.label).toSet();

    expect(labels, hasLength(CustomerFilter.values.length));
    expect(CustomerFilter.all.label, S.customersFilterAll);
  });
}
