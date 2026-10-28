import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';

/// عقد قراءة أرقام لوحة التحكم وكتابة هدف الشهر.
///
/// التنفيذ (Supabase) في `data/repositories`: اللوحة لا تسأل عن أي جدول، لأن
/// التجميع كلّه يجري داخل القاعدة ويصلها رقم جاهز للعرض.
abstract interface class DashboardRepository {
  /// يقرأ المقاييس كما ترجعها `admin_dashboard_metrics` للفروع التي يديرها الأدمن.
  Future<AdminDashboardMetrics> loadMetrics();

  /// يكتب هدف الشهر في `core.app_settings`، و`null` يمسحه.
  ///
  /// القاعدة ترفض الطلب لمن لا يملك `settings.write` وكل الفروع، فالواجهة لا
  /// تعيد اختبار الصلاحية، لكنها لا تُظهر زر التعديل لمن لا يملكها أصلًا.
  Future<void> saveRevenueTarget(double? value);
}
