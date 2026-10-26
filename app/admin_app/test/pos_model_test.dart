import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

Map<String, dynamic> _optionValue(
  String id, {
  String nameAr = '',
  String nameEn = '',
  Object? priceDelta,
  bool isDefault = false,
}) {
  return {
    'id': id,
    'name_ar': nameAr,
    'name_en': nameEn,
    'price_delta': priceDelta,
    'is_default': isDefault,
  };
}

Map<String, dynamic> _optionGroup({
  required String id,
  String nameAr = '',
  String nameEn = '',
  String selectionType = 'single',
  int minSelect = 0,
  Object? maxSelect,
  bool isRequired = false,
  List<Map<String, dynamic>> values = const <Map<String, dynamic>>[],
}) {
  return {
    'id': id,
    'name_ar': nameAr,
    'name_en': nameEn,
    'selection_type': selectionType,
    'min_select': minSelect,
    'max_select': maxSelect,
    'is_required': isRequired,
    'values': values,
  };
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('catalog', () {
    test('parses every section and resolves lookups', () {
      final catalog = PosCatalog.fromJson({
        'branch_id': 'b1',
        'currency_code': ' ',
        'tax_rate': '15',
        'tax_included': false,
        'branches': [
          {
            'id': 'b1',
            'code': 'MAADI',
            'name_ar': 'المعادي',
            'name_en': 'Maadi',
          },
          {'id': 'b2', 'name_ar': 'مدينة نصر'},
        ],
        'categories': [
          {
            'id': 'coffee',
            'name_ar': 'قهوة',
            'name_en': 'Coffee',
            'product_count': '3',
            'sort_order': 1,
          },
        ],
        'payment_methods': [
          {
            'id': 'pay-card',
            'code': 'card',
            'name_ar': 'بطاقة',
            'name_en': 'Card',
            'is_online': true,
            'sort_order': 1,
          },
          {
            'id': 'pay-cash',
            'code': 'cash',
            'name_ar': 'نقدي',
            'name_en': 'Cash',
            'sort_order': 2,
          },
          {
            'id': 'pay-apple',
            'code': 'apple_pay',
            'name_ar': 'أبل باي',
            'name_en': 'Apple Pay',
            'is_online': true,
            'sort_order': 3,
          },
        ],
        'products': [
          {
            'id': 'p-latte',
            'category_id': 'coffee',
            'name_ar': 'لاتيه',
            'name_en': 'Latte',
            'category_name_ar': 'قهوة',
            'category_name_en': 'Coffee',
            'unit_price': '20',
            'track_stock': true,
            'stock_quantity': '5',
          },
          'skip me',
        ],
      });

      expect(catalog.branchId, 'b1');
      expect(catalog.currencyCode, 'SAR');
      expect(catalog.taxRate, 15);
      expect(catalog.taxIncluded, isFalse);
      expect(catalog.branches, hasLength(2));
      expect(catalog.branches.first.code, 'MAADI');
      expect(
        catalog.branchById('b2')!.nameFor(AppLanguage.english),
        'مدينة نصر',
      );
      expect(catalog.branchById(null), isNull);
      expect(catalog.categories.single.productCount, 3);
      expect(catalog.categories.single.nameFor(AppLanguage.arabic), 'قهوة');
      expect(catalog.paymentById('pay-card')!.isOnline, isTrue);
      expect(catalog.paymentById('pay-card')!.sortOrder, 1);
      expect(catalog.paymentById(null), isNull);
      expect(catalog.paymentMethods, hasLength(2));
      expect(catalog.paymentById('pay-apple'), isNull);
      expect(
        catalog.paymentMethods.every((method) => method.isCounterTender),
        isTrue,
      );
      expect(catalog.preferredPaymentMethod!.id, 'pay-cash');
      expect(catalog.products.single.nameFor(AppLanguage.english), 'Latte');
      expect(catalog.products.single.stockLimit, 5);
      expect(catalog.productById('p-latte')!.unitPrice, 20);
      expect(catalog.productById('nope'), isNull);
    });

    test('defaults to SAR with tax included when the payload is sparse', () {
      final catalog = PosCatalog.fromJson(const <String, dynamic>{});

      expect(catalog.currencyCode, 'SAR');
      expect(catalog.taxIncluded, isTrue);
      expect(catalog.taxRate, 0);
      expect(catalog.branches, isEmpty);
      expect(catalog.categories, isEmpty);
      expect(catalog.paymentMethods, isEmpty);
      expect(catalog.products, isEmpty);
      expect(catalog.preferredPaymentMethod, isNull);
    });

    test('the preferred payment is cash even when it is not first', () {
      const catalog = PosCatalog(
        paymentMethods: [
          PosPaymentMethod(id: 'pay-card', code: 'card'),
          PosPaymentMethod(id: 'pay-cash', code: 'cash'),
        ],
      );

      expect(catalog.preferredPaymentMethod!.id, 'pay-cash');

      const wallets = PosCatalog(
        paymentMethods: [PosPaymentMethod(id: 'pay-wallet', code: 'wallet')],
      );
      expect(wallets.preferredPaymentMethod!.id, 'pay-wallet');
    });
  });

  group('product', () {
    test('parses prices, stock, discounts and option groups', () {
      final product = PosProduct.fromJson({
        'id': 'p-mocha',
        'category_id': 'special',
        'sku': 'MOCHA-01',
        'name_ar': 'موكا',
        'name_en': 'Mocha',
        'description_ar': 'قهوة بالشوكولاتة',
        'image_url': '   ',
        'prep_minutes': '4',
        'is_featured': true,
        'category_name_ar': 'عروض',
        'category_name_en': 'Specials',
        'unit_price': 20,
        'regular_price': 25,
        'discount_percentage': '20',
        'stock_quantity': '5',
        'track_stock': true,
        'option_groups': [
          _optionGroup(
            id: 'g-size',
            nameAr: 'الحجم',
            nameEn: 'Size',
            isRequired: true,
            maxSelect: 3,
            values: [
              _optionValue('v-small', nameAr: 'صغير', nameEn: 'Small'),
              _optionValue(
                'v-large',
                nameAr: 'كبير',
                nameEn: 'Large',
                priceDelta: '5',
                isDefault: true,
              ),
            ],
          ),
          _optionGroup(
            id: 'g-extras',
            nameAr: 'إضافات',
            nameEn: 'Extras',
            selectionType: 'multiple',
            maxSelect: 2,
            values: [
              _optionValue(
                'v-oat',
                nameAr: 'شوفان',
                nameEn: 'Oat milk',
                priceDelta: 2,
              ),
              _optionValue(
                'v-shot',
                nameAr: 'شوت',
                nameEn: 'Extra shot',
                priceDelta: 3,
              ),
            ],
          ),
        ],
      });

      expect(product.nameFor(AppLanguage.english), 'Mocha');
      expect(product.descriptionFor(AppLanguage.english), 'قهوة بالشوكولاتة');
      expect(product.categoryNameFor(AppLanguage.english), 'Specials');
      expect(product.imageUrl, isNull);
      expect(product.prepMinutes, 4);
      expect(product.isFeatured, isTrue);
      expect(product.unitPrice, 20);
      expect(product.hasDiscount, isTrue);
      expect(product.isSellable, isTrue);
      expect(product.hasOptions, isTrue);
      expect(product.stockLimit, 5);
      expect(product.matches('mocha-01'), isTrue);
      expect(product.matches('specials'), isTrue);
      expect(product.matches('موكا'), isTrue);
      expect(product.matches('coffee'), isFalse);

      final size = product.optionGroups.first;
      expect(size.nameFor(AppLanguage.arabic), 'الحجم');
      expect(size.isSingle, isTrue);
      expect(size.effectiveMin, 1);
      expect(size.effectiveMax, 1);
      expect(size.initialSelection.single.id, 'v-large');
      expect(size.accepts(1), isTrue);
      expect(size.accepts(0), isFalse);
      expect(size.accepts(2), isFalse);

      final extras = product.optionGroups.last;
      expect(extras.effectiveMin, 0);
      expect(extras.effectiveMax, 2);
      expect(extras.initialSelection, isEmpty);
      expect(extras.accepts(0), isTrue);
      expect(extras.accepts(2), isTrue);
      expect(extras.accepts(3), isFalse);
      expect(extras.values.first.priceDelta, 2);
    });

    test('a required group without defaults preselects its first value', () {
      final group = PosOptionGroup.fromJson(
        _optionGroup(
          id: 'g-size',
          isRequired: true,
          values: [_optionValue('v-1'), _optionValue('v-2')],
        ),
      );

      expect(group.initialSelection.single.id, 'v-1');
    });

    test('a sparse product defaults to available with fallback names', () {
      final product = PosProduct.fromJson({
        'id': 'p-tea',
        'name_ar': 'شاي',
        'description_en': 'Hot tea',
      });

      expect(product.isAvailable, isTrue);
      expect(product.isSellable, isTrue);
      expect(product.trackStock, isFalse);
      expect(product.hasDiscount, isFalse);
      expect(product.nameFor(AppLanguage.english), 'شاي');
      expect(product.descriptionFor(AppLanguage.english), 'Hot tea');
      expect(product.categoryNameFor(AppLanguage.english), isEmpty);
      expect(product.matches(''), isTrue);
      expect(product.matches('coffee'), isFalse);
    });

    test('stock limits respect tracking, negative stock and availability', () {
      const untracked = PosProduct(id: 'p');
      expect(untracked.stockLimit, isNull);

      const tracked = PosProduct(id: 'p', trackStock: true, stockQuantity: 3);
      expect(tracked.stockLimit, 3);

      const negativeAllowed = PosProduct(
        id: 'p',
        trackStock: true,
        stockQuantity: 3,
        allowNegative: true,
      );
      expect(negativeAllowed.stockLimit, isNull);

      const missing = PosProduct(id: 'p', trackStock: true, stockQuantity: -2);
      expect(missing.stockLimit, 0);

      const unavailable = PosProduct(id: 'p', isAvailable: false);
      expect(unavailable.isSellable, isFalse);
      expect(unavailable.hasOptions, isFalse);

      const soldOut = PosProduct(id: 'p', soldOut: true);
      expect(soldOut.isSellable, isFalse);
    });

    test('names fall back to the other language', () {
      const branch = PosBranch(id: 'b1', nameAr: 'المعادي');
      const category = PosCategory(id: 'c1', nameEn: 'Coffee');
      const payment = PosPaymentMethod(id: 'pay', nameAr: 'نقدي');
      const value = PosOptionValue(id: 'v1', nameEn: 'Large');
      const group = PosOptionGroup(id: 'g1', nameAr: 'الحجم');

      expect(branch.nameFor(AppLanguage.english), 'المعادي');
      expect(category.nameFor(AppLanguage.arabic), 'Coffee');
      expect(payment.nameFor(AppLanguage.english), 'نقدي');
      expect(value.nameFor(AppLanguage.arabic), 'Large');
      expect(group.nameFor(AppLanguage.english), 'الحجم');
    });

    test('selection and fulfillment types parse case-insensitively', () {
      expect(
        PosSelectionType.fromValue(' MULTIPLE '),
        PosSelectionType.multiple,
      );
      expect(PosSelectionType.fromValue(null), PosSelectionType.single);
      expect(
        PosFulfillmentType.fromValue(' DINE_IN '),
        PosFulfillmentType.dineIn,
      );
      expect(PosFulfillmentType.fromValue('pickup'), PosFulfillmentType.pickup);
      expect(
        PosFulfillmentType.fromValue('anything'),
        PosFulfillmentType.dineIn,
      );
      expect(PosFulfillmentType.fromValue(null), PosFulfillmentType.dineIn);
      expect(PosFulfillmentType.dineIn.isDineIn, isTrue);
    });
  });

  group('cart', () {
    const latte = PosProduct(
      id: 'p-latte',
      nameAr: 'لاتيه',
      nameEn: 'Latte',
      unitPrice: 20,
    );
    const large = PosOptionValue(
      id: 'v-large',
      nameAr: 'كبير',
      nameEn: 'Large',
      priceDelta: 5,
    );

    test('a line prices the base and options and labels them', () {
      final line = PosCartLine(
        product: latte,
        options: const [large],
        quantity: 2,
      );

      expect(line.optionsTotal, 5);
      expect(line.unitPrice, 25);
      expect(line.lineTotal, 50);
      expect(line.optionsLabel(AppLanguage.english), 'Large');
      expect(line.optionsLabel(AppLanguage.arabic), 'كبير');

      final copy = line.copyWith(quantity: 3);
      expect(copy.quantity, 3);
      expect(copy.lineTotal, 75);
      expect(copy.options, hasLength(1));
      expect(copy.note, isEmpty);
    });

    test('prices round to two decimals like the server', () {
      final line = PosCartLine(
        product: const PosProduct(id: 'p', unitPrice: 0.1),
        options: const [PosOptionValue(id: 'o', priceDelta: 0.2)],
      );

      expect(line.unitPrice, 0.3);
      expect(line.lineTotal, 0.3);
    });

    test('a catalogue discount keeps the regular price for the invoice', () {
      final line = PosCartLine(
        product: const PosProduct(
          id: 'p-mocha',
          unitPrice: 30,
          regularPrice: 36,
        ),
        options: const [large],
        quantity: 2,
      );

      expect(line.unitPrice, 35);
      expect(line.regularUnitPrice, 41);
      expect(line.lineTotal, 70);
      expect(line.beforeDiscountTotal, 82);
      expect(line.discountTotal, 12);
      expect(line.hasDiscount, isTrue);

      final regular = PosCartLine(
        product: const PosProduct(id: 'p-latte', unitPrice: 20),
        quantity: 2,
      );
      expect(regular.regularUnitPrice, 20);
      expect(regular.hasDiscount, isFalse);
      expect(regular.discountTotal, 0);
    });

    test('keys merge identical options regardless of order and keep notes', () {
      final plain = PosCartLine.cartKey(
        productId: 'p',
        optionIds: const ['b', 'a'],
        note: '  ',
      );
      final reordered = PosCartLine.cartKey(
        productId: 'p',
        optionIds: const ['a', 'b'],
      );
      final noted = PosCartLine.cartKey(
        productId: 'p',
        optionIds: const ['a', 'b'],
        note: ' extra hot ',
      );

      expect(plain, reordered);
      expect(noted, isNot(plain));
      expect(noted, contains('extra hot'));
    });

    test('the summary adds tax only when it is not included', () {
      final lines = [
        PosCartLine(product: latte, quantity: 2),
        PosCartLine(product: const PosProduct(id: 'p-cake', unitPrice: 15)),
      ];

      final included = PosCartSummary.fromLines(
        lines,
        taxRate: 15,
        taxIncluded: true,
      );
      expect(included.subtotal, 55);
      expect(included.tax, 0);
      expect(included.total, 55);
      expect(included.quantity, 3);
      expect(included.isEmpty, isFalse);

      final added = PosCartSummary.fromLines(
        lines,
        taxRate: 15,
        taxIncluded: false,
      );
      expect(added.tax, 8.25);
      expect(added.total, 63.25);

      final noRate = PosCartSummary.fromLines(
        lines,
        taxRate: 0,
        taxIncluded: false,
      );
      expect(noRate.tax, 0);
      expect(noRate.total, 55);

      const empty = PosCartSummary();
      expect(empty.isEmpty, isTrue);
      expect(empty.total, 0);
    });

    test('tax rounds to two decimals', () {
      final summary = PosCartSummary.fromLines(
        [PosCartLine(product: const PosProduct(id: 'p', unitPrice: 33.33))],
        taxRate: 15,
        taxIncluded: false,
      );

      expect(summary.tax, 5);
      expect(summary.total, 38.33);
    });

    test('discounts split the total before and after the catalogue saving', () {
      final lines = [
        PosCartLine(product: latte, quantity: 2),
        PosCartLine(
          product: const PosProduct(
            id: 'p-mocha',
            unitPrice: 30,
            regularPrice: 36,
          ),
          options: const [large],
        ),
      ];

      final included = PosCartSummary.fromLines(
        lines,
        taxRate: 15,
        taxIncluded: true,
      );
      expect(included.subtotal, 75);
      expect(included.discount, 6);
      expect(included.beforeDiscount, 81);
      expect(included.hasDiscount, isTrue);
      expect(included.tax, 0);
      expect(included.vat, 9.78);
      expect(included.total, 75);
      expect(included.taxable, 65.22);

      final added = PosCartSummary.fromLines(
        lines,
        taxRate: 15,
        taxIncluded: false,
      );
      expect(added.discount, 6);
      expect(added.tax, 11.25);
      expect(added.vat, 11.25);
      expect(added.total, 86.25);
      expect(added.taxable, 75);

      final noDiscount = PosCartSummary.fromLines(
        [PosCartLine(product: latte)],
        taxRate: 0,
        taxIncluded: true,
      );
      expect(noDiscount.hasDiscount, isFalse);
      expect(noDiscount.beforeDiscount, 20);
      expect(noDiscount.vat, 0);
      expect(noDiscount.taxable, 20);
    });
  });

  group('order result', () {
    test('parses the server answer for the receipt', () {
      final result = PosOrderResult.fromJson({
        'order_id': 'o1',
        'order_number': 'POS-2026-000042',
        'subtotal': '30',
        'tax_total': 4.5,
        'grand_total': '34.5',
        'currency_code': ' ',
        'fulfillment_type': ' DINE_IN ',
        'table_number': ' 7 ',
        'payment_method_id': 'pay-cash',
        'payment_method_code': 'cash',
        'payment_method_name_ar': 'نقدي',
        'payment_method_name_en': 'Cash',
        'customer_id': 'c1',
        'customer_name': ' أحمد محمد ',
        'customer_phone': ' 01000000000 ',
        'customer_source': 'registered',
        'placed_at': '2026-10-26T09:30:00Z',
        'reused': 'true',
      });

      expect(result.orderId, 'o1');
      expect(result.orderNumber, 'POS-2026-000042');
      expect(result.subtotal, 30);
      expect(result.taxTotal, 4.5);
      expect(result.grandTotal, 34.5);
      expect(result.currencyCode, 'SAR');
      expect(result.fulfillmentType, PosFulfillmentType.dineIn);
      expect(result.tableNumber, '7');
      expect(result.paymentMethodId, 'pay-cash');
      expect(result.paymentMethodCode, 'cash');
      expect(result.paymentMethodNameFor(AppLanguage.english), 'Cash');
      expect(result.paymentMethodNameFor(AppLanguage.arabic), 'نقدي');
      expect(result.customerId, 'c1');
      expect(result.customerDisplayName, 'أحمد محمد');
      expect(result.customerPhone, '01000000000');
      expect(result.customerSource, 'registered');
      expect(result.hasCustomer, isTrue);
      expect(result.placedAt, DateTime.utc(2026, 10, 26, 9, 30));
      expect(result.reused, isTrue);
    });

    test('parses the invoice summary and the seller tax identity', () {
      final result = PosOrderResult.fromJson({
        'order_id': 'o7',
        'order_number': 'POS-2026-000047',
        'subtotal': 75,
        'grand_total': 75,
        'currency_code': 'SAR',
        'product_discount_total': 6,
        'discount_total': '0',
        'before_discount_total': 81,
        'taxable_total': 65.22,
        'vat_total': 9.78,
        'tax_rate': 15,
        'tax_included': true,
        'seller_name_ar': 'مقهى النخبة',
        'seller_name_en': 'Elite Cafe',
        'seller_legal_name': 'مقهى النخبة للتجارة',
        'seller_vat_number': '310123456789003',
        'seller_address_ar': 'الرياض - حي العليا',
        'seller_address_en': 'Riyadh - Olaya',
        'seller_phone': '0112345678',
      });

      expect(result.discountAmount, 6);
      expect(result.beforeDiscount, 81);
      expect(result.invoiceVat, 9.78);
      expect(result.invoiceTaxable, 65.22);
      expect(result.hasVat, isTrue);
      expect(result.hasSellerVatNumber, isTrue);
      expect(result.hasSellerIdentity, isTrue);
      expect(
        result.sellerLegalNameFor(AppLanguage.english),
        'مقهى النخبة للتجارة',
      );
      expect(result.sellerNameFor(AppLanguage.english), 'Elite Cafe');
      expect(result.sellerAddressFor(AppLanguage.arabic), 'الرياض - حي العليا');
      expect(result.sellerAddressFor(AppLanguage.english), 'Riyadh - Olaya');
      expect(result.sellerPhone, '0112345678');
      expect(result.taxRate, 15);
      expect(result.taxIncluded, isTrue);

      final derived = PosOrderResult.fromJson(const {
        'order_id': 'o8',
        'order_number': 'POS-2026-000048',
        'subtotal': 100,
        'grand_total': 115,
        'tax_rate': 15,
      });
      expect(derived.invoiceVat, 15);
      expect(derived.invoiceTaxable, 100);
      expect(derived.hasVat, isTrue);
      expect(derived.hasSellerIdentity, isFalse);

      final legacy = PosOrderResult.fromJson(const {
        'order_id': 'o9',
        'order_number': 'POS-2026-000049',
        'subtotal': 40,
        'tax_total': 6,
        'grand_total': 46,
      });
      expect(legacy.invoiceVat, 6);
      expect(legacy.invoiceTaxable, 40);
      expect(legacy.discountAmount, 0);
      expect(legacy.beforeDiscount, 40);
    });

    test('a sparse result defaults to a dine-in sale and SAR', () {
      final result = PosOrderResult.fromJson(const {
        'order_id': 'o2',
        'order_number': 'POS-2026-000043',
        'table_number': '   ',
        'payment_method_name_ar': 'نقدي',
      });

      expect(result.currencyCode, 'SAR');
      expect(result.fulfillmentType, PosFulfillmentType.dineIn);
      expect(result.tableNumber, isNull);
      expect(result.customerDisplayName, isEmpty);
      expect(result.hasCustomer, isFalse);
      expect(result.placedAt, isNull);
      expect(result.reused, isFalse);
      expect(result.paymentMethodNameFor(AppLanguage.english), 'نقدي');
    });

    test('parses split tenders and keeps the primary method', () {
      final result = PosOrderResult.fromJson({
        'order_id': 'o4',
        'order_number': 'POS-2026-000044',
        'grand_total': 46,
        'currency_code': 'SAR',
        'payment_method_id': 'pay-card',
        'payment_method_code': 'card',
        'payment_method_name_ar': 'بطاقة',
        'payment_method_name_en': 'Card',
        'payments': [
          {
            'method_id': 'pay-cash',
            'method_code': 'cash',
            'method_name_ar': 'نقدي',
            'method_name_en': 'Cash',
            'amount': '10',
          },
          {
            'method_id': 'pay-card',
            'method_code': 'card',
            'method_name_ar': 'بطاقة',
            'method_name_en': 'Card',
            'amount': 36,
          },
        ],
      });

      expect(result.isSplitPayment, isTrue);
      expect(result.tenders, hasLength(2));
      expect(result.tenders.first.isCash, isTrue);
      expect(result.tenders.first.amount, 10);
      expect(result.tenders.first.nameFor(AppLanguage.english), 'Cash');
      expect(result.tenders.last.isCard, isTrue);
      expect(result.tenders.last.amount, 36);
      expect(result.paymentMethodId, 'pay-card');
    });

    test('a single-method response falls back to one tender', () {
      final result = PosOrderResult.fromJson({
        'order_id': 'o5',
        'order_number': 'POS-2026-000045',
        'grand_total': 20,
        'payment_method_id': 'pay-cash',
        'payment_method_code': 'cash',
        'payment_method_name_ar': 'نقدي',
      });

      expect(result.isSplitPayment, isFalse);
      expect(result.payments, isEmpty);
      expect(result.tenders, hasLength(1));
      expect(result.tenders.single.amount, 20);
      expect(result.tenders.single.nameFor(AppLanguage.english), 'نقدي');

      const free = PosOrderResult(orderId: 'o6', orderNumber: 'POS-6');
      expect(free.tenders, isEmpty);
      expect(free.isSplitPayment, isFalse);
    });
  });

  group('shift', () {
    test('parses the open drawer and its cash movements', () {
      final shift = PosShift.fromJson({
        'id': 's1',
        'branch_id': 'b1',
        'status': ' open ',
        'opening_float': '100',
        'cash_sales': 40,
        'card_sales': '25.5',
        'sales_total': 65.5,
        'order_count': '3',
        'cash_in': 10,
        'cash_out': 5,
        'expected_cash': 145,
        'currency_code': ' ',
        'opened_by_name': ' منى علي ',
        'opened_at': '2026-10-26T08:05:00Z',
        'note': ' بداية اليوم ',
        'already_open': 'true',
        'movements': [
          {
            'id': 'm1',
            'kind': 'cash_in',
            'amount': '10',
            'reason': ' فكة ',
            'created_by_name': 'منى علي',
            'created_at': '2026-10-26T09:00:00Z',
          },
          {'id': 'm2', 'kind': ' cash_out ', 'amount': 5, 'reason': 'مستلزمات'},
        ],
      });

      expect(shift.id, 's1');
      expect(shift.branchId, 'b1');
      expect(shift.isOpen, isTrue);
      expect(shift.isClosed, isFalse);
      expect(shift.openingFloat, 100);
      expect(shift.cashSales, 40);
      expect(shift.cardSales, 25.5);
      expect(shift.salesTotal, 65.5);
      expect(shift.orderCount, 3);
      expect(shift.cashIn, 10);
      expect(shift.cashOut, 5);
      expect(shift.expectedCash, 145);
      expect(shift.expectedDrawer, 145);
      expect(shift.cashNet, 5);
      expect(shift.countedCash, isNull);
      expect(shift.variance, isNull);
      expect(shift.hasVariance, isFalse);
      expect(shift.currencyCode, 'SAR');
      expect(shift.openedByName, 'منى علي');
      expect(shift.openedAt, DateTime.utc(2026, 10, 26, 8, 5));
      expect(shift.note, 'بداية اليوم');
      expect(shift.alreadyOpen, isTrue);
      expect(shift.movements, hasLength(2));
      expect(shift.movements.first.isCashIn, isTrue);
      expect(shift.movements.first.amount, 10);
      expect(shift.movements.first.reason, 'فكة');
      expect(shift.movements.first.createdByName, 'منى علي');
      expect(shift.movements.first.createdAt, DateTime.utc(2026, 10, 26, 9));
      expect(shift.movements.last.kind, PosCashMovementKind.cashOut);
      expect(shift.movements.last.isCashIn, isFalse);
    });

    test('a closed drawer exposes the counted cash and variance', () {
      final shift = PosShift.fromJson(const {
        'id': 's2',
        'branch_id': 'b1',
        'status': 'CLOSED',
        'opening_float': 100,
        'expected_cash': 145,
        'counted_cash': '140',
        'variance': -5,
        'closed_by_name': 'أحمد',
        'closed_at': '2026-10-26T22:00:00Z',
        'close_note': 'نقص في الفكة',
      });

      expect(shift.isClosed, isTrue);
      expect(shift.isOpen, isFalse);
      expect(shift.countedCash, 140);
      expect(shift.variance, -5);
      expect(shift.hasVariance, isTrue);
      expect(shift.isShort, isTrue);
      expect(shift.isOver, isFalse);
      expect(shift.closedByName, 'أحمد');
      expect(shift.closedAt, DateTime.utc(2026, 10, 26, 22));
      expect(shift.closeNote, 'نقص في الفكة');
    });

    test('variance states follow the counted difference', () {
      const balanced = PosShift(
        id: 's3',
        branchId: 'b1',
        status: PosShiftStatus.closed,
        expectedCash: 145,
        countedCash: 145,
        variance: 0,
      );
      expect(balanced.hasVariance, isFalse);
      expect(balanced.isShort, isFalse);
      expect(balanced.isOver, isFalse);

      const over = PosShift(
        id: 's4',
        branchId: 'b1',
        status: PosShiftStatus.closed,
        expectedCash: 145,
        countedCash: 147,
        variance: 2,
      );
      expect(over.hasVariance, isTrue);
      expect(over.isOver, isTrue);
      expect(over.isShort, isFalse);

      final sparse = PosShift.fromJson(const {'id': 's5'});
      expect(sparse.status, PosShiftStatus.open);
      expect(sparse.currencyCode, 'SAR');
      expect(sparse.movements, isEmpty);
      expect(sparse.alreadyOpen, isFalse);
    });
  });
}
