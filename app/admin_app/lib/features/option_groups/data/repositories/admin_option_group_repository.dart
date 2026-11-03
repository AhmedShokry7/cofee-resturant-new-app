import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';

/// يقرأ ويكتب مجموعات الأحجام والإضافات في لوحة التحكم.
///
/// الكتابات كلها تمرّ بالجسور في `public` كما تفعل الباقات والمنتجات: 030 منح
/// `authenticated` كتابة الجداول الأصلية و032 قراءة الجسور، وصلاحيات الجسر
/// نفسه من افتراضات Supabase في `public`، فبقيت سياسات 020 و224 و225 هي التي
/// تقرر لكل صفّ. فلا تتظاهر الطبقة هنا بفحص صلاحية تعرف القاعدة أنها أَدقّ.
class AdminOptionGroupRepository implements OptionGroupRepository {
  AdminOptionGroupRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminOptionGroup>> loadGroups() async {
    // القراءات الأربع مستقلّة، فتُفتح معًا بدل أن تنتظر كل واحدة سابقتها.
    final answers = await Future.wait(<Future<List<Map<String, dynamic>>>>[
      _rows('option_groups', '*', orderedBy: 'sort_order'),
      _rows('option_values', '*', orderedBy: 'sort_order'),
      _rows('option_group_categories', 'group_id, category_id'),
      _rows('product_option_groups', 'group_id, product_id, is_excluded'),
    ]);

    final groups = answers[0];
    final valuesByGroup = _groupBy(answers[1], 'group_id');
    final categoriesByGroup = _groupBy(answers[2], 'group_id');
    final bindingsByGroup = _groupBy(answers[3], 'group_id');

    return groups
        .map((row) {
          final key = '${row['id']}';
          final bindings =
              bindingsByGroup[key] ?? const <Map<String, dynamic>>[];
          return AdminOptionGroup.fromJson(row).copyWith(
            values: (valuesByGroup[key] ?? const <Map<String, dynamic>>[])
                .map(AdminOptionValue.fromJson)
                .toList(growable: false),
            categoryIds:
                categoriesByGroup[key]
                    ?.map((r) => '${r['category_id']}')
                    .toList(growable: false) ??
                const <String>[],
            productIds: bindings
                .where((r) => r['is_excluded'] != true)
                .map((r) => '${r['product_id']}')
                .toList(growable: false),
            excludedProductIds: bindings
                .where((r) => r['is_excluded'] == true)
                .map((r) => '${r['product_id']}')
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<AdminOptionGroup> createGroup(AdminOptionGroup group) async {
    final row = await _supabase
        .from('option_groups')
        .insert(group.toRow())
        .select()
        .single();
    final created = AdminOptionGroup.fromJson(row);
    await _insertValues(created.id, group.values);
    await _replaceScope(created.id, group);
    return group.copyWith(id: created.id);
  }

  @override
  Future<AdminOptionGroup> updateGroup(AdminOptionGroup group) async {
    // الحذف أولًا: هو الفعل الذي قد ترفضه القاعدة بقيد 23503 لأن القيمة بيعت
    // في طلب سابق. تقديمه يعني أن الرفض يترك اللوحة كما كانت، لا نصف تعديل.
    await _deleteRemovedValues(group);

    await _supabase
        .from('option_groups')
        .update(group.toRow())
        .eq('id', group.id);

    final kept = group.values.where((v) => v.id.isNotEmpty);
    for (final value in kept) {
      await _supabase
          .from('option_values')
          .update(value.toRow())
          .eq('id', value.id);
    }
    await _insertValues(
      group.id,
      group.values.where((v) => v.id.isEmpty).toList(growable: false),
    );

    await _replaceScope(group.id, group);
    return group;
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    // الربط يرتبط بقيد RESTRICT، فلا يُحذف صفّ المجموعة قبله، والقيم تُحذف
    // خلفه بتسلسل 008 (ON DELETE CASCADE).
    await _supabase
        .from('product_option_groups')
        .delete()
        .eq('group_id', groupId);
    await _supabase
        .from('option_group_categories')
        .delete()
        .eq('group_id', groupId);
    await _supabase.from('option_groups').delete().eq('id', groupId);
  }

  @override
  Future<void> setGroupActive(String groupId, bool isActive) async {
    await _supabase
        .from('option_groups')
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', groupId);
  }

  Future<void> _insertValues(
    String groupId,
    List<AdminOptionValue> values,
  ) async {
    if (values.isEmpty) return;
    await _supabase.from('option_values').insert([
      for (final value in values) {...value.toRow(), 'group_id': groupId},
    ]);
  }

  /// يحذف قيم المجموعة التي لم تعد في القائمة، بعد أن يقرأ ما هو مخزّن فعلًا.
  Future<void> _deleteRemovedValues(AdminOptionGroup group) async {
    final stored = await _supabase
        .from('option_values')
        .select('id')
        .eq('group_id', group.id);
    final keptIds = group.values.map((v) => v.id).toSet();
    final removed = (stored as List)
        .whereType<Map>()
        .map((row) => '${row['id']}')
        .where((id) => !keptIds.contains(id))
        .toList(growable: false);
    if (removed.isEmpty) return;
    await _supabase.from('option_values').delete().inFilter('id', removed);
  }

  /// يستبدل صفوف النطاق كلها: جداول صغيرة، والقراءة بعدها هي ما تحلّه دالة 224.
  Future<void> _replaceScope(String groupId, AdminOptionGroup group) async {
    await _supabase
        .from('option_group_categories')
        .delete()
        .eq('group_id', groupId);
    await _supabase
        .from('product_option_groups')
        .delete()
        .eq('group_id', groupId);

    if (group.scope == AdminOptionGroupScope.category &&
        group.categoryIds.isNotEmpty) {
      await _supabase.from('option_group_categories').insert([
        for (var index = 0; index < group.categoryIds.length; index++)
          <String, dynamic>{
            'group_id': groupId,
            'category_id': group.categoryIds[index],
            'sort_order': index,
          },
      ]);
    }

    final boundProducts = group.scope == AdminOptionGroupScope.products
        ? group.productIds.map((id) => (id: id, excluded: false))
        : group.excludedProductIds.map((id) => (id: id, excluded: true));
    final rows = [
      for (final entry in boundProducts)
        <String, dynamic>{
          'group_id': groupId,
          'product_id': entry.id,
          'is_excluded': entry.excluded,
        },
    ];
    if (rows.isEmpty) return;
    await _supabase.from('product_option_groups').insert(rows);
  }

  /// يجميع صفوفًا تحت مفتاحها، فتُقرأ القيم والنطاق في رحلة واحدة لكل جدول
  /// بدل سؤال مجموعة مجموعة.
  Map<String, List<Map<String, dynamic>>> _groupBy(
    List<Map<String, dynamic>> rows,
    String column,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent('${row[column]}', () => <Map<String, dynamic>>[])
          .add(row);
    }
    return grouped;
  }

  Future<List<Map<String, dynamic>>> _rows(
    String table,
    String columns, {
    String? orderedBy,
  }) async {
    final select = _supabase.from(table).select(columns);
    final rows = orderedBy == null
        ? await select
        : await select.order(orderedBy);
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
