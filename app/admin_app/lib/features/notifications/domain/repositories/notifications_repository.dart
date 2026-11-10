import 'dart:typed_data';

import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';

/// نتيجة تعديل إشعار (قراءة أو حذف) كما تعيدها القاعدة.
enum NotificationMutationOutcome { success, notFound, failed }

/// مصدر حجم صفحة الإشعارات الوحيد في التطبيق.
///
/// `admin_notifications` في القاعدة يسعّى `p_limit` إلى المدى 1..100 وافتراضيه
/// 20، لذا يرسل الأدمن العدد صراحةً في كل طلب: يبقى هذا الثابت هو العدد الذي
/// تُبنى عليه صفحات اللوحة (`total ~/ pageSize`) وهو العدد الذي يُطلب من SQL،
/// فلا ينقلب الترقيم لو تغيّر الافتراضي في جهة.
abstract final class AdminNotificationsPaging {
  AdminNotificationsPaging._();

  static const int pageSize = 10;
}

/// عقد قراءة الإشعارات ومؤشراتها وحالة الدفع وكتابة إرسالها وتعديلها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class NotificationsRepository {
  /// يقرأ صفحة الإشعارات مع فلاتر البحث والنوع والقراءة والدفع والترقيم.
  Future<AdminNotificationPage> loadNotifications({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    String? source,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 0,
    int pageSize = AdminNotificationsPaging.pageSize,
  });

  /// يقرأ ملخص مؤشرات الإشعارات.
  Future<AdminNotificationMetrics> loadMetrics();

  /// يقرأ حالة إعداد الدفع (Push) في المشروع.
  Future<AdminPushHealth> loadPushHealth();

  /// يقرأ العملاء المطابقين للبحث داخل مُنشئ الإشعار.
  Future<List<AdminNotificationComposerCustomer>> loadCustomers({
    String? search,
    int limit = 20,
  });

  /// يقرأ تقدير حجم الجمهور قبل الإرسال.
  Future<AdminAudienceEstimate> loadAudience({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  });

  /// يرسل الإشعار ويعيد نتيجة الإرسال كما تعيدها القاعدة.
  Future<AdminSendResult> sendNotification({
    required AdminNotificationType type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required AdminNotificationAudience audience,
    String? customerId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  });

  /// يرفع صورة الحملة إلى دلو الصور العام ويعيد رابطها العام.
  ///
  /// الصورة تُرفع قبل الإرسال لأن وظيفة الدفع تحتاج رابطًا يصل إليه الجهاز
  /// مباشرة؛ لا سر فيه ولا توقيع انتهاء صلاحيته، لذا يُقبل الدلو العام وحده.
  Future<String> uploadCampaignImage({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  /// يحذف ملف صورة الحملة من الدلو، ويتجاهل أي رابط ليس ملفًا في هذا الدلو.
  Future<void> deleteCampaignImageFile(String? imageUrl);

  /// يعيد إرسال إشعار ويعيد النتيجة كما تعيدها القاعدة.
  Future<AdminResendResult> resendNotification(String notificationId);

  /// يعلّم الإشعار مقروءًا أو غير مقروء ويعيد نتيجة العملية.
  Future<NotificationMutationOutcome> setRead(String notificationId, bool read);

  /// يحذف الإشعار ويعيد نتيجة العملية.
  Future<NotificationMutationOutcome> deleteNotification(String notificationId);
}
