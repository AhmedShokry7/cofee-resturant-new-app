import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';

AdminCustomer _customer({
  String id = 'c1',
  String? name,
  String? email,
  String? phone,
}) => AdminCustomer(id: id, fullName: name, email: email, phone: phone);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('amounts and counts', () {
    test('use western numerals and grouped thousands in English', () {
      expect(customerMoney(1234.5), '1,234.50');
      expect(customerCount(1234), '1,234');
      expect(customerPercent(4.8), '4.8%');
      expect(customerPercent(50), '50%');
    });

    test('use Arabic-Indic numerals and separators in Arabic', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);

      expect(customerMoney(1234.5), '١٬٢٣٤٫٥٠');
      expect(customerCount(1234), '١٬٢٣٤');
      expect(customerPercent(4.8), '٤٫٨٪');
    });

    test('speak the order count in the active language', () {
      expect(customerOrders(0), '0 orders');
      expect(customerOrders(1), '1 order');
      expect(customerOrders(3), '3 orders');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(customerOrders(1), 'طلب واحد');
      expect(customerOrders(3), '٣ طلبات');
    });
  });

  group('dates', () {
    test('show the month name in the active language', () {
      final date = DateTime(2024, 3, 12);

      expect(customerDate(date), '12 Mar 2024');
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(customerDate(date), '١٢ مارس ٢٠٢٤');
      expect(customerDate(null), '—');
    });

    test('describe today and yesterday with their time', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 5);
      final previous = now.subtract(const Duration(days: 1));
      final yesterday = DateTime(
        previous.year,
        previous.month,
        previous.day,
        9,
        15,
      );

      expect(customerLastOrder(today), 'Today, 2:05 PM');
      expect(customerLastOrder(yesterday), 'Yesterday, 9:15 AM');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(customerLastOrder(today), 'اليوم، ٢:٠٥ م');
    });

    test('fall back to the date for older orders and to a label for none', () {
      expect(customerLastOrder(DateTime(2024, 3, 12)), '12 Mar 2024');
      expect(customerLastOrder(null), S.customersNoLastOrder);

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(customerLastOrder(DateTime(2024, 3, 12)), '١٢ مارس ٢٠٢٤');
    });
  });

  group('identity', () {
    test('prefers the name, then the email, then the id', () {
      expect(customerDisplayName(_customer(name: ' Ahmed ')), 'Ahmed');
      expect(
        customerDisplayName(_customer(email: 'ahmed@example.com')),
        'ahmed@example.com',
      );
      expect(customerDisplayName(_customer()), 'c1');
    });

    test('shows a contact line that differs from the display name', () {
      expect(
        customerContactLine(
          _customer(name: 'Ahmed', email: 'ahmed@example.com'),
        ),
        'ahmed@example.com',
      );
      expect(
        customerContactLine(_customer(email: 'ahmed@example.com')),
        isNull,
      );
      expect(
        customerContactLine(
          _customer(name: 'Ahmed', email: '', phone: '0500000000'),
        ),
        '0500000000',
      );
    });

    test('builds initials from the first and last word', () {
      expect(customerInitials(_customer(name: 'Ahmed Shokry')), 'AS');
      expect(customerInitials(_customer(name: 'Ahmed')), 'A');
      expect(customerInitials(_customer(name: 'Ahmed  Said  Shokry')), 'AS');
      expect(customerInitials(_customer(email: 'sara@example.com')), 'S');
    });
  });
}
