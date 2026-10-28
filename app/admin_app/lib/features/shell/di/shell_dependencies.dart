import 'package:admin_app/core/services/postgres_changes_feed.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/shell/data/repositories/admin_nav_repository.dart';
import 'package:admin_app/features/shell/domain/repositories/nav_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الهيكل داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class ShellDependencies {
  ShellDependencies._();

  static NavRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static NavRepository get repository => _repository ??= AdminNavRepository();

  /// القناة الحيّة التي تُتح بها العدّادات: جداول الصفحات التي يملك الموظف
  /// فتحها فقط. تُعاد `null` حين لا توجد قناة تُفتح، فيبقى الاستطلاع وحده.
  static PostgresChangesFeed? newLiveFeed({
    required bool watchOrders,
    required bool watchKitchen,
  }) {
    if (!SupabaseService.isReady) return null;
    return PostgresChangesFeed(
      channelPrefix: 'admin-nav-live',
      tables: <RealtimeTable>[
        if (watchOrders) const RealtimeTable('orders', 'orders'),
        if (watchKitchen) const RealtimeTable('kitchen', 'tickets'),
      ],
    );
  }
}
