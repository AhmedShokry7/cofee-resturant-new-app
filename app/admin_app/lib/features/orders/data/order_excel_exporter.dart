import 'package:file_picker/file_picker.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/catalog/data/product_excel_service.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

class OrderExcelExporter {
  static Future<bool> save(List<AdminOrder> orders) async {
    final rows = <List<String>>[
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
    ];
    final bytes = ProductExcelService.buildWorkbook(rows);
    final date = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.saveFile(
      dialogTitle: S.ordersExportExcel,
      fileName: 'orders-$date.xlsx',
      bytes: bytes,
    );
    return path != null;
  }
}
