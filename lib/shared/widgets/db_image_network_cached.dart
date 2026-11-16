import 'package:new_coffee/shared/widgets/db_image_network_cached_impl.dart';

/// The default (non-web) door: the cached implementation itself.
///
/// الباب الافتراضي خارج الويب: نفس التطبيق المخزّن مؤقتًا.
class DbNetworkImageImpl extends DbCachedNetworkImage {
  const DbNetworkImageImpl({
    super.key,
    required super.url,
    required super.fit,
    required super.alignment,
    super.width,
    super.height,
    required super.iconSize,
  });
}
