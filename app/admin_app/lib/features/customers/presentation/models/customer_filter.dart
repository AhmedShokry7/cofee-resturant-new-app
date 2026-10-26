import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';

enum CustomerFilter { all, vip, blacklisted, buyers, noOrders }

extension CustomerFilterView on CustomerFilter {
  String get label => switch (this) {
    CustomerFilter.all => S.customersFilterAll,
    CustomerFilter.vip => S.customersFilterVip,
    CustomerFilter.blacklisted => S.customersFilterBlacklisted,
    CustomerFilter.buyers => S.customersFilterBuyers,
    CustomerFilter.noOrders => S.customersFilterNoOrders,
  };

  bool matches(AdminCustomer customer) => switch (this) {
    CustomerFilter.all => true,
    CustomerFilter.vip => customer.isVip,
    CustomerFilter.blacklisted => customer.isBlacklisted,
    CustomerFilter.buyers => customer.ordersCount > 0,
    CustomerFilter.noOrders => customer.ordersCount == 0,
  };
}

List<AdminCustomer> filterCustomers(
  List<AdminCustomer> customers, {
  String search = '',
  CustomerFilter filter = CustomerFilter.all,
}) {
  final query = search.trim().toLowerCase();
  return customers
      .where((customer) {
        if (!filter.matches(customer)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          customer.fullName ?? '',
          customer.email ?? '',
          customer.phone ?? '',
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}
