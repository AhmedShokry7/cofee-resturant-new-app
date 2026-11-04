import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// حقل زيادة خيار واحد لهذا المشروب وحده.
///
/// الحقل فارغ يعني لا تجاوز: صفّ `catalog.product_option_value_pricing` محذوف،
/// فتُعمل زيادة المجموعة كما كانت قبل 229. لذا لا يُكتب الصفر في الحقل ولا
/// يُرسَل، لأنه سيصبح سعرًا خاصًا قيمته صفر.
class ProductOptionPriceField extends StatelessWidget {
  const ProductOptionPriceField({
    super.key,
    required this.valueId,
    required this.controller,
    required this.groupDelta,
  });

  final String valueId;
  final TextEditingController controller;
  final double groupDelta;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('product-option-price-$valueId'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.start,
      decoration: adminDialogFieldDecoration(
        context,
        label: S.ownDeltaLabel,
        hint: localizeDigits(formatDelta(groupDelta)),
      ).copyWith(suffix: const CurrencyIcon(size: 15)),
    );
  }
}
