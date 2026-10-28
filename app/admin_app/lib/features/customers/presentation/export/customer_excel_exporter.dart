import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/excel_report_saver.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';

/// The customers row set written to a workbook.
class CustomerExcelExporter {
  const CustomerExcelExporter._();

  static Future<bool> save(List<AdminCustomer> customers) =>
      ExcelReportSaver.save(
        dialogTitle: S.customersExport,
        baseName: 'customers',
        rows: <List<String>>[
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
              customer.createdAt == null
                  ? ''
                  : formatDateTime(customer.createdAt),
              customer.isVip ? S.yes : S.no,
              customer.isBlacklisted ? S.yes : S.no,
            ],
        ],
      );
}
