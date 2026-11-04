import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/option_groups/data/repositories/option_group_rows.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';

/// يكتب زيادة خيار لمشروب وحده في `catalog.product_option_value_pricing`.
///
/// `null` يمحُ الصفّ، والامحاء رجوع إلى زيادة المجموعة لا صفر: الفرق بين
/// «٣ ريالات لهذا الحجم في هذا المشروب» و«الزيادة كما تقررها المجموعة».
Future<void> writeOptionValuePrice(
  SupabaseClient client,
  String productId,
  String valueId,
  double? delta,
) async {
  if (delta == null) {
    await client
        .from('product_option_value_pricing')
        .delete()
        .eq('product_id', productId)
        .eq('value_id', valueId);
    return;
  }
  await updateThenInsert(
    client,
    'product_option_value_pricing',
    match: {'product_id': productId, 'value_id': valueId},
    values: {'price_delta': delta},
    returning: 'value_id',
  );
}

/// يكتب صفّ ربط مجموعة بمشروب في `catalog.product_option_groups`.
///
/// النطاق يقرر معنى الصفّ: مجموعة `products` وجودُ صفّها ربط، ومجموعة `all` أو
/// `category` وجودُه استثناءٌ أي فصل. واللوحة تسأل النطاق ولا تفترضه، لأن
/// `catalog.effective_product_option_groups` في 224 هو وحده من يجيب العميل.
Future<void> writeProductOptionBinding(
  SupabaseClient client, {
  required String productId,
  required String groupId,
  required AdminOptionGroupScope scope,
  required bool attached,
}) async {
  final bindsProducts = scope == AdminOptionGroupScope.products;
  final match = {'product_id': productId, 'group_id': groupId};
  if (bindsProducts ? !attached : attached) {
    await client
        .from('product_option_groups')
        .delete()
        .eq('product_id', productId)
        .eq('group_id', groupId);
    return;
  }
  await updateThenInsert(
    client,
    'product_option_groups',
    match: match,
    values: {'is_excluded': !bindsProducts},
    returning: 'group_id',
  );
}
