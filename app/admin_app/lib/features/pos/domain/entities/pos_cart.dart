import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';

double posRound2(double value) => (value * 100).roundToDouble() / 100;

/// One configured product line in the cashier's basket.
class PosCartLine {
  PosCartLine({
    required this.product,
    List<PosOptionValue> options = const <PosOptionValue>[],
    this.quantity = 1,
    this.note = '',
  }) : options = List<PosOptionValue>.unmodifiable(options);

  final PosProduct product;
  final List<PosOptionValue> options;
  final int quantity;
  final String note;

  /// The key merges identical configurations and keeps different notes apart.
  String get key => cartKey(
    productId: product.id,
    optionIds: [for (final option in options) option.id],
    note: note,
  );

  double get optionsTotal =>
      posRound2(options.fold(0, (sum, option) => sum + option.priceDelta));

  double get unitPrice => posRound2(product.unitPrice + optionsTotal);

  /// The catalogue list price before the product's own discount.
  double get regularUnitPrice {
    final regular = product.regularPrice;
    final base = regular > product.unitPrice ? regular : product.unitPrice;
    return posRound2(base + optionsTotal);
  }

  double get lineTotal => posRound2(unitPrice * quantity);

  double get beforeDiscountTotal => posRound2(regularUnitPrice * quantity);

  double get discountTotal => posRound2(beforeDiscountTotal - lineTotal);

  bool get hasDiscount => discountTotal > 0;

  String optionsLabel(AppLanguage language) {
    final names = <String>[
      for (final option in options)
        if (option.nameFor(language).isNotEmpty) option.nameFor(language),
    ];
    return names.join(' · ');
  }

  PosCartLine copyWith({int? quantity, String? note}) {
    return PosCartLine(
      product: product,
      options: options,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  static String cartKey({
    required String productId,
    required Iterable<String> optionIds,
    String note = '',
  }) {
    final sortedOptions = optionIds.toList(growable: false)..sort();
    final normalizedNote = note.trim();
    return '$productId|${sortedOptions.join(',')}|$normalizedNote';
  }
}

/// The money the cart will charge, matching the server-side totals.
class PosCartSummary {
  const PosCartSummary({
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.vat = 0,
    this.total = 0,
    this.quantity = 0,
  });

  /// The total after product discounts, before any added tax.
  final double subtotal;
  final double discount;

  /// Tax added on top of [subtotal] when prices exclude tax.
  final double tax;

  /// The VAT portion inside [total], whether the price included it or added it.
  final double vat;
  final double total;
  final int quantity;

  bool get isEmpty => quantity == 0;

  bool get hasDiscount => discount > 0;

  double get beforeDiscount => posRound2(subtotal + discount);

  double get taxable => posRound2(total - vat);

  factory PosCartSummary.fromLines(
    Iterable<PosCartLine> lines, {
    required double taxRate,
    required bool taxIncluded,
  }) {
    var subtotal = 0.0;
    var beforeDiscount = 0.0;
    var quantity = 0;
    for (final line in lines) {
      subtotal += line.lineTotal;
      beforeDiscount += line.beforeDiscountTotal;
      quantity += line.quantity;
    }
    subtotal = posRound2(subtotal);
    final discount = posRound2(posRound2(beforeDiscount) - subtotal);
    final tax = taxIncluded || taxRate <= 0
        ? 0.0
        : posRound2(subtotal * taxRate / 100);
    final total = posRound2(subtotal + tax);
    final vat = taxIncluded && taxRate > 0
        ? posRound2(total * taxRate / (100 + taxRate))
        : tax;
    return PosCartSummary(
      subtotal: subtotal,
      discount: discount > 0 ? discount : 0,
      tax: tax,
      vat: vat,
      total: total,
      quantity: quantity,
    );
  }
}
