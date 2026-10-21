import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
/// عميل مخصص للقراءة فقط، يتصل بـ Read Replica إذا كان مفعّلاً.
///
/// إذا لم يُوفر رابط Read Replica عبر [AppConfig.supabaseReadUrl]،
/// يُرجع العميل الأساسي [SupabaseService.client] للسلامة.
class SupabaseReadService {
  SupabaseReadService._();

  static SupabaseClient? _readClient;

  /// العميل الأساسي (للقراءة والكتابة) — موجود أصلاً في [SupabaseService.client].
  static SupabaseClient get write => SupabaseService.client;

  /// عميل القراءة. إذا كان رابط Read Replica مُوفرًا، يُنشأ عميل منفصل موجه إليه.
  /// وإلا يُرجع العميل الأساسي.
  static SupabaseClient get read {
    if (_readClient != null) return _readClient!;

    if (AppConfig.hasReadReplica) {
      _readClient = SupabaseClient(
        AppConfig.supabaseReadUrl,
        AppConfig.supabasePublishableKey,
      );
      return _readClient!;
    }

    return SupabaseService.client;
  }
}
