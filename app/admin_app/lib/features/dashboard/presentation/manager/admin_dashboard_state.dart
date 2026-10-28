import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';

/// حالات قراءة اللوحة.
enum AdminDashboardStatus { initial, loading, ready, failure }

/// حالات حفظ هدف الشهر، منفصلة عن حالة القراءة.
///
/// فصلها مقصود: فشل حفظ الهدف لا يُخفي اللوحة كلها، واللوحة التي تقرأ بنجاح
/// يمكن أن يكون هدفها في طور الحفظ. حالة واحدة تخلط الاثنين تجعل زر الحفظ
/// يعطّل الشاشة.
enum AdminDashboardTargetStatus { idle, saving, failure }

class AdminDashboardState {
  const AdminDashboardState({
    this.status = AdminDashboardStatus.initial,
    this.metrics = AdminDashboardMetrics.empty,
    this.errorMessage,
    this.targetStatus = AdminDashboardTargetStatus.idle,
    this.targetError,
    this.searchQuery = '',
    this.salesRangeDays = dashboardMonthRangeDays,
  });

  final AdminDashboardStatus status;
  final AdminDashboardMetrics metrics;
  final String? errorMessage;
  final AdminDashboardTargetStatus targetStatus;
  final String? targetError;

  /// نص البحث في ترويسة اللوحة: يصفّي الأسطر المعروضة ولا يفتح صفحة أخرى.
  final String searchQuery;

  /// عدد الأيام المرسوم في منحنى المبيعات، ويختاره الأدمن من مفتاح اللوحة.
  final int salesRangeDays;

  bool get isLoading => status == AdminDashboardStatus.loading;
  bool get isFailure => status == AdminDashboardStatus.failure;
  bool get isSavingTarget => targetStatus == AdminDashboardTargetStatus.saving;

  /// البحث جاهزًا للمقارنة: مفرّغ ومنخفض الحروف.
  String get query => searchQuery.trim().toLowerCase();

  /// اللوحة تحمل أرقامًا تُعرض، حتى لو كان مجموعها صفرًا.
  ///
  /// بهذا فقط يبقى الرقم على الشاشة أثناء التحديث بدل أن تختفي اللوحة كلها
  /// كل مرة يضغط فيها الأدمن «تحديث».
  bool get hasMetrics => metrics.hasAnyOrder;

  AdminDashboardState copyWith({
    AdminDashboardStatus? status,
    AdminDashboardMetrics? metrics,
    String? errorMessage,
    bool clearError = false,
    AdminDashboardTargetStatus? targetStatus,
    String? targetError,
    bool clearTargetError = false,
    String? searchQuery,
    int? salesRangeDays,
  }) {
    return AdminDashboardState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      targetStatus: targetStatus ?? this.targetStatus,
      targetError: clearTargetError ? null : (targetError ?? this.targetError),
      searchQuery: searchQuery ?? this.searchQuery,
      salesRangeDays: salesRangeDays ?? this.salesRangeDays,
    );
  }
}
