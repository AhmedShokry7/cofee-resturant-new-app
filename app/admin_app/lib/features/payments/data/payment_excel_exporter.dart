import 'package:file_picker/file_picker.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/catalog/data/product_excel_service.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';

class PaymentExcelExporter {
  static Future<bool> save(List<AdminPayment> payments) async {
    final rows = <List<String>>[
      [
        S.orderNumber,
        S.customer,
        S.provider,
        S.reference,
        S.amount,
        S.currencyCode,
        S.paymentStatusLabelTitle,
        S.paidAt,
        S.refundedAt,
        S.paymentCard,
        S.verifiedByServer,
      ],
      for (final payment in payments)
        [
          (payment.orderNumber?.trim().isNotEmpty ?? false)
              ? payment.orderNumber!.trim()
              : payment.id,
          (payment.customerName?.trim().isNotEmpty ?? false)
              ? payment.customerName!.trim()
              : S.unknownCustomer,
          payment.provider,
          payment.providerReference ?? '',
          formatAmount(payment.amount),
          payment.currencyCode,
          S.paymentStatusLabel(payment.status),
          formatDateTime(payment.paidAt),
          formatDateTime(payment.refundedAt),
          _card(payment),
          payment.verifiedByServer ? S.yes : S.no,
        ],
    ];
    final bytes = ProductExcelService.buildWorkbook(rows);
    final date = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.saveFile(
      dialogTitle: S.paymentsExport,
      fileName: 'payments-$date.xlsx',
      bytes: bytes,
    );
    return path != null;
  }

  static String _card(AdminPayment payment) {
    final brand = payment.cardBrand?.trim() ?? '';
    final last4 = payment.cardLast4?.trim() ?? '';
    if (last4.isEmpty) return brand;
    return brand.isEmpty ? '**** $last4' : '$brand **** $last4';
  }
}
