import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_receipt_dialog.dart';

const _latte = PosProduct(
  id: 'p-latte',
  nameAr: 'لاتيه',
  nameEn: 'Latte',
  unitPrice: 20,
);

/// فاتورة مكتملة الهوية الضريبية: لها رمز QR ولها زر طباعة يعمل.
PosReceipt _invoiceReadyReceipt() => PosReceipt(
  result: const PosOrderResult(
    orderId: 'o1',
    orderNumber: 'POS-2026-000042',
    subtotal: 40,
    taxTotal: 6,
    grandTotal: 46,
    currencyCode: 'SAR',
    paymentMethodNameAr: 'نقدي',
    taxRate: 15,
    taxIncluded: true,
    sellerLegalName: 'مقهى النخبة للتجارة',
    sellerVatNumber: '310123456789003',
  ),
  lines: [PosCartLine(product: _latte, quantity: 2)],
);

/// فاتورة بلا رقم ضريبي: لا تُطبع لأن الفاتورة الضريبية لا تُصدر ناقصة.
PosReceipt _withoutSeller() => const PosReceipt(
  result: PosOrderResult(
    orderId: 'o2',
    orderNumber: 'POS-2026-000043',
    subtotal: 20,
    grandTotal: 20,
    currencyCode: 'EGP',
    paymentMethodNameAr: 'نقدي',
  ),
);

Future<void> _open(WidgetTester tester, PosReceipt receipt) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPosReceiptDialog(context, receipt),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

Finder _printButton() => find.widgetWithText(FilledButton, S.posPrintReceipt);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  testWidgets('the invoice prints on any device, not only in a browser', (
    tester,
  ) async {
    await _open(tester, _invoiceReadyReceipt());

    // لا بوابة «الطباعة متاحة في المتصفح» بعد الآن: الزر مُفعّل مهما كان الجهاز.
    expect(_printButton(), findsOneWidget);
    expect(tester.widget<FilledButton>(_printButton()).onPressed, isNotNull);

    // تحميل الخطوط ورسم الـ PDF ثم قناة الطباعة يعمل كلها خارج حلقة الوهم،
    // فالتنفيذ الحقيقي يحتاج حدثًا حقيقيًا من نظام التشغيل.
    await tester.runAsync(() async {
      // الطباعة التلقائية عند فتح البطاقة تستهلك الزر حتى تنتهي.
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_printButton()).onPressed, isNotNull);

      await tester.tap(_printButton());
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pump();
    });

    expect(
      find.text(S.posReceiptPrintFailed),
      findsOneWidget,
      reason: 'تتعذر الطباعة حين لا توجد خدمة طباعة، لا حين لا يوجد متصفح',
    );
  });

  testWidgets('a sale without the tax identity keeps printing closed', (
    tester,
  ) async {
    await _open(tester, _withoutSeller());
    await tester.pump();

    expect(tester.widget<FilledButton>(_printButton()).onPressed, isNull);
  });
}
