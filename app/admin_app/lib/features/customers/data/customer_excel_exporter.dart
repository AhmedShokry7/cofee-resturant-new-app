import 'package:file_picker/file_picker.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/services/product_excel_service.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';

class CustomerExcelExporter {
  static Future<bool> save(List<AdminCustomer> customers) async {
    final rows = <List<String>>[
      [
        S.customerName,
        S.customerEmailLabel,
        S.customerPhoneLabel,
        S.ordersCountLabel,
        S.totalSpent,
        S.lastOrder,
        S.customersJoinDate,
        S.vip,
        S.blacklist,
      ],
      for (final customer in customers)
        [
          customerDisplayName(customer),
          customer.email ?? '',
          customer.phone ?? '',
          '${customer.ordersCount}',
          formatAmount(customer.totalSpent),
          customer.lastOrderAt == null
              ? ''
              : formatDateTime(customer.lastOrderAt),
          customer.createdAt == null ? '' : formatDateTime(customer.createdAt),
          customer.isVip ? S.yes : S.no,
          customer.isBlacklisted ? S.yes : S.no,
        ],
    ];
    final bytes = ProductExcelService.buildWorkbook(rows);
    final date = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.saveFile(
      dialogTitle: S.customersExport,
      fileName: 'customers-$date.xlsx',
      bytes: bytes,
    );
    return path != null;
  }
}
