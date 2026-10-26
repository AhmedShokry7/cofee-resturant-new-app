import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/pos/data/models/pos_cart.dart';
import 'package:admin_app/features/pos/data/models/pos_catalog.dart';
import 'package:admin_app/features/pos/data/models/pos_json.dart';

/// One cash or card portion of the order's payment.
class PosTender {
  const PosTender({
    required this.methodId,
    this.code = '',
    this.nameAr = '',
    this.nameEn = '',
    this.amount = 0,
  });

  final String methodId;
  final String code;
  final String nameAr;
  final String nameEn;
  final double amount;

  bool get isCash => code == 'cash';

  bool get isCard => code == 'card';

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosTender.fromJson(Map<String, dynamic> json) {
    return PosTender(
      methodId: posText(json['method_id']),
      code: posText(json['method_code']),
      nameAr: posText(json['method_name_ar']),
      nameEn: posText(json['method_name_en']),
      amount: posNumber(json['amount']),
    );
  }
}

/// The server's answer after a counter sale, used for the receipt.
class PosOrderResult {
  const PosOrderResult({
    required this.orderId,
    required this.orderNumber,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.currencyCode = 'SAR',
    this.fulfillmentType = PosFulfillmentType.dineIn,
    this.tableNumber,
    this.paymentMethodId = '',
    this.paymentMethodCode = '',
    this.paymentMethodNameAr = '',
    this.paymentMethodNameEn = '',
    this.payments = const <PosTender>[],
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerSource,
    this.placedAt,
    this.reused = false,
    this.productDiscountTotal = 0,
    this.discountTotal = 0,
    this.beforeDiscountTotal = 0,
    this.taxableTotal = 0,
    this.vatTotal = 0,
    this.taxRate = 0,
    this.taxIncluded = true,
    this.sellerNameAr = '',
    this.sellerNameEn = '',
    this.sellerLegalName = '',
    this.sellerVatNumber = '',
    this.sellerAddressAr = '',
    this.sellerAddressEn = '',
    this.sellerPhone = '',
  });

  final String orderId;
  final String orderNumber;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final String currencyCode;
  final PosFulfillmentType fulfillmentType;
  final String? tableNumber;
  final String paymentMethodId;
  final String paymentMethodCode;
  final String paymentMethodNameAr;
  final String paymentMethodNameEn;
  final List<PosTender> payments;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerSource;
  final DateTime? placedAt;

  /// The catalogue discount across the sold lines.
  final double productDiscountTotal;
  final double discountTotal;
  final double beforeDiscountTotal;

  /// The taxable amount and the VAT portion of [grandTotal].
  final double taxableTotal;
  final double vatTotal;
  final double taxRate;
  final bool taxIncluded;

  /// The seller identity printed on the simplified tax invoice.
  final String sellerNameAr;
  final String sellerNameEn;
  final String sellerLegalName;
  final String sellerVatNumber;
  final String sellerAddressAr;
  final String sellerAddressEn;
  final String sellerPhone;

  /// The full discount shown on the invoice (catalogue plus order discount).
  double get discountAmount {
    final total = productDiscountTotal + discountTotal;
    return total > 0 ? posRound2(total) : 0;
  }

  double get beforeDiscount {
    if (beforeDiscountTotal > 0) return beforeDiscountTotal;
    return posRound2(subtotal + discountAmount);
  }

  /// The VAT portion, derived from an inclusive total when the server did not
  /// send one (an older backend without the invoice summary).
  double get invoiceVat {
    if (vatTotal > 0) return vatTotal;
    if (taxTotal > 0) return taxTotal;
    if (taxRate > 0 && taxIncluded) {
      return posRound2(grandTotal * taxRate / (100 + taxRate));
    }
    return 0;
  }

  double get invoiceTaxable {
    if (taxableTotal > 0) return taxableTotal;
    return posRound2(grandTotal - invoiceVat);
  }

  bool get hasVat => invoiceVat > 0;

  bool get hasSellerVatNumber => sellerVatNumber.trim().isNotEmpty;

  bool get hasSellerIdentity =>
      hasSellerVatNumber && sellerLegalNameFor(AppLanguage.arabic).isNotEmpty;

  String sellerLegalNameFor(AppLanguage language) {
    final legal = sellerLegalName.trim();
    if (legal.isNotEmpty) return legal;
    return sellerNameFor(language);
  }

  String sellerNameFor(AppLanguage language) {
    final primary = language.isArabic ? sellerNameAr : sellerNameEn;
    final fallback = language.isArabic ? sellerNameEn : sellerNameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  String sellerAddressFor(AppLanguage language) {
    final primary = language.isArabic ? sellerAddressAr : sellerAddressEn;
    final fallback = language.isArabic ? sellerAddressEn : sellerAddressAr;
    final address = primary.trim();
    return address.isNotEmpty ? address : fallback.trim();
  }

  /// The tenders of this sale, falling back to the single primary method for
  /// responses from a server without split-payment support.
  List<PosTender> get tenders {
    if (payments.isNotEmpty) return payments;
    if (grandTotal <= 0 || paymentMethodId.isEmpty) return const <PosTender>[];
    return <PosTender>[
      PosTender(
        methodId: paymentMethodId,
        code: paymentMethodCode,
        nameAr: paymentMethodNameAr,
        nameEn: paymentMethodNameEn,
        amount: grandTotal,
      ),
    ];
  }

  bool get isSplitPayment => payments.length > 1;

  String get customerDisplayName => customerName?.trim() ?? '';

  bool get hasCustomer => customerDisplayName.isNotEmpty;

  /// True when the same idempotency key recovered an already-created order.
  final bool reused;

  String paymentMethodNameFor(AppLanguage language) {
    final primary = language.isArabic
        ? paymentMethodNameAr
        : paymentMethodNameEn;
    final fallback = language.isArabic
        ? paymentMethodNameEn
        : paymentMethodNameAr;
    final name = primary.trim();
    return name.isNotEmpty ? name : fallback.trim();
  }

  factory PosOrderResult.fromJson(Map<String, dynamic> json) {
    return PosOrderResult(
      orderId: posText(json['order_id']),
      orderNumber: posText(json['order_number']),
      subtotal: posNumber(json['subtotal']),
      taxTotal: posNumber(json['tax_total']),
      grandTotal: posNumber(json['grand_total']),
      currencyCode: posText(json['currency_code']).isEmpty
          ? 'SAR'
          : posText(json['currency_code']),
      fulfillmentType: PosFulfillmentType.fromValue(json['fulfillment_type']),
      tableNumber: posTextOrNull(json['table_number']),
      paymentMethodId: posText(json['payment_method_id']),
      paymentMethodCode: posText(json['payment_method_code']),
      paymentMethodNameAr: posText(json['payment_method_name_ar']),
      paymentMethodNameEn: posText(json['payment_method_name_en']),
      payments: posMaps(json['payments'])
          .map(PosTender.fromJson)
          .toList(growable: false),
      customerId: posTextOrNull(json['customer_id']),
      customerName: posTextOrNull(json['customer_name']),
      customerPhone: posTextOrNull(json['customer_phone']),
      customerSource: posTextOrNull(json['customer_source']),
      placedAt: posDate(json['placed_at']),
      reused: posFlag(json['reused']),
      productDiscountTotal: posNumber(json['product_discount_total']),
      discountTotal: posNumber(json['discount_total']),
      beforeDiscountTotal: posNumber(json['before_discount_total']),
      taxableTotal: posNumber(json['taxable_total']),
      vatTotal: posNumber(json['vat_total']),
      taxRate: posNumber(json['tax_rate']),
      taxIncluded: !json.containsKey('tax_included')
          ? true
          : posFlag(json['tax_included']),
      sellerNameAr: posText(json['seller_name_ar']),
      sellerNameEn: posText(json['seller_name_en']),
      sellerLegalName: posText(json['seller_legal_name']),
      sellerVatNumber: posText(json['seller_vat_number']),
      sellerAddressAr: posText(json['seller_address_ar']),
      sellerAddressEn: posText(json['seller_address_en']),
      sellerPhone: posText(json['seller_phone']),
    );
  }
}
