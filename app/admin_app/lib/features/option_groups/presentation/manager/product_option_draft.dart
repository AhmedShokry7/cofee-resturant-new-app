import 'package:flutter/widgets.dart';

import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';

/// نصّ حقول حوار المشروب: من يملك المتحكمات، وما تغيّر فيها عن جواب القاعدة.
///
/// الحقل الفارغ ليس صفرًا بل «لا تجاوز»، فلا يُرسل إلا الفرق: ما كتبته اللوحة
/// ولم ترد به القاعدة بعد. والملف وحده يعرف أي خيار صار له تجاوز وأيهم لم يعد.
class ProductOptionDraft {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  Map<String, TextEditingController> get controllers => _controllers;

  /// يخلق حقلًا لكل خيار جديد ويملؤه من القاعدة، ولا يمسّ ما هو قيد الكتابة.
  void ensure(List<AdminProductOptionGroup> groups) {
    for (final group in groups) {
      for (final value in group.values) {
        if (_controllers.containsKey(value.id)) continue;
        _controllers[value.id] = TextEditingController(text: _textOf(value));
      }
    }
  }

  /// إعادة ملء بعد كتابة نجحت: ما تقرأه اللوحة هو ما ردّت به القاعدة.
  void fill(List<AdminProductOptionGroup> groups) {
    for (final group in groups) {
      for (final value in group.values) {
        final controller = _controllers[value.id];
        if (controller == null) continue;
        final text = _textOf(value);
        if (controller.text != text) controller.text = text;
      }
    }
  }

  /// الزيادات التي تُكتب الآن: `null` تمحو تجاوز الخيار فتعيده للمجموعة.
  Map<String, double?> changes(List<AdminProductOptionGroup> groups) {
    final changes = <String, double?>{};
    for (final group in groups.where((g) => g.isAttached)) {
      for (final value in group.values) {
        final typed = _typed(value.id);
        if (typed == value.overrideDelta) continue;
        changes[value.id] = typed;
      }
    }
    return changes;
  }

  double? _typed(String valueId) {
    final text = normalizeDigits((_controllers[valueId]?.text ?? '').trim());
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static String _textOf(AdminProductOptionValue value) =>
      value.hasOwnPrice ? formatAmount(value.overrideDelta ?? 0) : '';

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
