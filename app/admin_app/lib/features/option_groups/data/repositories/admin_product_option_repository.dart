import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/option_groups/data/repositories/option_group_rows.dart';
import 'package:admin_app/features/option_groups/data/repositories/product_option_assembler.dart';
import 'package:admin_app/features/option_groups/data/repositories/product_option_writes.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_default_sizes.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';

/// يقرأ ما يسري على مشروب واحد ويكتب أسعاره وربطه، عبر جسور `public`.
///
/// الكتابتان تمرّان بالسياسات نفسها: `catalog.product.write` في 229 للتسعير
/// وفي 020 و224 للربط، فاللوحة لا تفحص صلاحية تعرف القاعدة أنها أَدقّ فيها.
class AdminProductOptionRepository implements ProductOptionRepository {
  AdminProductOptionRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminProductOptionGroup>> loadForProduct(String productId) async {
    await _ensureDefaultSizeGroup();
    // القراءات مستقلّة فتُفتح معًا: المجموعات وقيمها، وجواب 224 لهذا المشروب،
    // ثم تجاوزات 229 عنده.
    final answers = await Future.wait(<Future<List<Map<String, dynamic>>>>[
      bridgeRows(_supabase, 'option_groups', '*', orderedBy: 'sort_order'),
      bridgeRows(_supabase, 'option_values', '*', orderedBy: 'sort_order'),
      bridgeRows(
        _supabase,
        'product_option_groups_effective',
        'group_id, is_required',
        productId: productId,
      ),
      bridgeRows(
        _supabase,
        'product_option_value_pricing',
        'value_id, price_delta',
        productId: productId,
      ),
    ]);
    return assembleProductOptionGroups(
      groups: answers[0],
      values: answers[1],
      effective: answers[2],
      pricing: answers[3],
    );
  }

  /// يضمن مجموعة المقاسات القياسية عند فتح محرر المنتج، كي لا يضطر المستخدم
  /// لإنشائها يدويًا من صفحة الإضافات. الربط بالمنتج يظل اختيارًا من المحرر.
  Future<void> _ensureDefaultSizeGroup() async {
    final groups = await bridgeRows(
      _supabase,
      'option_groups',
      'id, code, name_ar, name_en, selection_type, min_select, max_select, is_required, is_active',
    );
    final sizeGroups = groups.where((row) {
      return AdminDefaultSizes.isSizeGroup(
        code: '${row['code'] ?? ''}',
        nameAr: '${row['name_ar'] ?? ''}',
        nameEn: '${row['name_en'] ?? ''}',
      );
    });
    final existing = sizeGroups.isEmpty ? null : sizeGroups.first;

    final groupId = existing == null
        ? await _createDefaultSizeGroup()
        : '${existing['id']}';

    if (existing != null) {
      final changes = <String, dynamic>{};
      if (existing['selection_type'] != 'single') {
        changes['selection_type'] = 'single';
      }
      if (existing['min_select'] != 0) changes['min_select'] = 0;
      if (existing['max_select'] != 1) changes['max_select'] = 1;
      if (existing['is_required'] == true) changes['is_required'] = false;
      if (existing['is_active'] == false) changes['is_active'] = true;
      if (changes.isNotEmpty) {
        await _supabase.from('option_groups').update(changes).eq('id', groupId);
      }
    }

    final storedValues = await bridgeRows(
      _supabase,
      'option_values',
      '*',
      orderedBy: 'sort_order',
    );
    final groupValues = storedValues
        .where((row) => '${row['group_id']}' == groupId)
        .toList(growable: false);
    final retained = <String>{};

    for (var index = 0; index < AdminDefaultSizes.values.length; index++) {
      final standard = AdminDefaultSizes.values[index];
      final matches = groupValues.where((row) {
        final code = '${row['code'] ?? ''}'.toLowerCase();
        final nameAr = '${row['name_ar'] ?? ''}'.trim();
        final nameEn = '${row['name_en'] ?? ''}'.trim().toLowerCase();
        return code == standard.code ||
            nameAr == standard.nameAr ||
            nameEn == standard.nameEn.toLowerCase();
      });
      final value = matches.isEmpty ? null : matches.first;
      if (value == null) {
        final created = await _supabase
            .from('option_values')
            .insert({
              'group_id': groupId,
              'code': standard.code,
              'name_ar': standard.nameAr,
              'name_en': standard.nameEn,
              'price_delta': 0,
              'sort_order': index,
              'is_default': false,
              'is_active': true,
            })
            .select('id')
            .single();
        retained.add('${created['id']}');
      } else {
        final id = '${value['id']}';
        retained.add(id);
        final changes = <String, dynamic>{};
        if (value['name_ar'] != standard.nameAr) {
          changes['name_ar'] = standard.nameAr;
        }
        if (value['name_en'] != standard.nameEn) {
          changes['name_en'] = standard.nameEn;
        }
        if (value['sort_order'] != index) changes['sort_order'] = index;
        if (value['is_active'] == false) changes['is_active'] = true;
        if (changes.isNotEmpty) {
          await _supabase.from('option_values').update(changes).eq('id', id);
        }
      }
    }

    for (final value in groupValues) {
      final id = '${value['id']}';
      if (!retained.contains(id) && value['is_active'] != false) {
        await _supabase
            .from('option_values')
            .update({'is_active': false})
            .eq('id', id);
      }
    }
  }

  Future<String> _createDefaultSizeGroup() async {
    final row = await _supabase
        .from('option_groups')
        .insert({
          'code': AdminDefaultSizes.groupCode,
          'name_ar': 'الحجم',
          'name_en': 'Size',
          'selection_type': 'single',
          'min_select': 0,
          'max_select': 1,
          'is_required': false,
          'sort_order': 0,
          'is_active': true,
          'applies_to': 'products',
        })
        .select('id')
        .single();
    return '${row['id']}';
  }

  @override
  Future<void> setValuePrice(String productId, String valueId, double? delta) =>
      writeOptionValuePrice(_supabase, productId, valueId, delta);

  @override
  Future<void> setGroupAttached(
    String productId,
    String groupId,
    bool attached,
  ) async {
    // النطاق هو الذي يقرر أي صفّ يغيّر جواب 224، فاللوحة تسأله لا تفترضه.
    final group = await _supabase
        .from('option_groups')
        .select('applies_to')
        .eq('id', groupId)
        .single();
    await writeProductOptionBinding(
      _supabase,
      productId: productId,
      groupId: groupId,
      scope: AdminOptionGroupScope.fromKey(group['applies_to'] as String?),
      attached: attached,
    );
  }
}
