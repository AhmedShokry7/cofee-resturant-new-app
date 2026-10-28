import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/excel_report_saver.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/core/models/order_status.dart';

/// The orders row set written to a workbook: the columns of the directory, in
/// the order the screen shows them.
class OrderExcelExporter {
  const OrderExcelExporter._();

  static Future<bool> save(List<AdminOrder> orders) => ExcelReportSaver.save(
    dialogTitle: S.ordersExportExcel,
    baseName: 'orders',
    rows: <List<String>>[
      [
        S.orderNumber,
        S.customer,
        S.date,
        S.fulfillmentType,
        S.ordersStatus,
        S.paymentStatusLabelTitle,
        S.total,
      ],
      for (final order in orders)
        [
          order.orderNumber,
          order.customerName ?? S.ordersUnknownCustomer,
          formatDateTime(order.placedAt),
          OrderFulfillmentView.of(order.fulfillmentType).label,
          OrderStatusView.of(order.status).label,
          OrderPaymentStatusView.of(order.paymentStatus).label,
          formatAmount(order.grandTotal),
        ],
    ],
  );
}
