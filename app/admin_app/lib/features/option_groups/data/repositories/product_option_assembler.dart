import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';

/// يبني مجموعات المشروب من صفوف الجسور الأربعة، بعيدًا عن الرحلة إليها.
///
/// الفصل هنا يترك المستودع أسئلةً وكتابةً خالصين، ويجعل القرار — مَن المرفوع
/// ومَن المتجاوز — دالةً تُختبر بلا قاعدة.
List<AdminProductOptionGroup> assembleProductOptionGroups({
  required List<Map<String, dynamic>> groups,
  required List<Map<String, dynamic>> values,
  required List<Map<String, dynamic>> effective,
  required List<Map<String, dynamic>> pricing,
}) {
  // جواب `effective_product_option_groups` وحده يقول هل يرى المشروب المجموعة.
  final requiredByGroup = <String, bool>{
    for (final row in effective)
      '${row['group_id']}': row['is_required'] == true,
  };
  final overrides = <String, double>{
    for (final row in pricing)
      '${row['value_id']}': (row['price_delta'] as num?)?.toDouble() ?? 0,
  };
  final valuesByGroup = <String, List<Map<String, dynamic>>>{};
  for (final row in values) {
    valuesByGroup
        .putIfAbsent('${row['group_id']}', () => <Map<String, dynamic>>[])
        .add(row);
  }

  return <AdminProductOptionGroup>[
    for (final row in groups)
      // مجموعة موقوفة أو قيمة موقوفة لا يراهما العميل أصلًا، فلا معنى
      // لتسعيرهما من هنا؛ شؤونهما في صفحة المجموعات.
      if (row['is_active'] != false)
        AdminProductOptionGroup.fromJson(
          row,
          isAttached: requiredByGroup.containsKey('${row['id']}'),
          isRequired: requiredByGroup['${row['id']}'] ?? false,
          values: <AdminProductOptionValue>[
            for (final value
                in valuesByGroup['${row['id']}'] ??
                    const <Map<String, dynamic>>[])
              // القيم تصل بالترتيب الذي قرأ به المستودع.
              if (value['is_active'] != false)
                AdminProductOptionValue.fromJson(
                  value,
                  overrideDelta: overrides['${value['id']}'],
                ),
          ],
        ),
  ];
}
