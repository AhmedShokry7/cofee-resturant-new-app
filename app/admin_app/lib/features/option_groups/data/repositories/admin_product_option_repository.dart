import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/option_groups/data/repositories/option_group_rows.dart';
import 'package:admin_app/features/option_groups/data/repositories/product_option_assembler.dart';
import 'package:admin_app/features/option_groups/data/repositories/product_option_writes.dart';
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
