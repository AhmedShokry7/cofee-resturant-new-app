import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';

/// تنفيذ كتابة واحدة، وإعادة رفض القاعدة إن رُفضت.
///
/// لا تُكتب هنا أي رسالة جاهزة: الرفض يبقى كما رفعته 212 برمزها ونصها، تقرأه
/// الشاشة وترجمه إن عرفته. تجميع الاستثناءات في موضع واحد يمنع كل شاشة أن
/// تقرر وحدها أن مجهولًا هو «نقص صلاحية».
Future<HrRefusal?> hrAttempt(Future<void> Function() send) async {
  try {
    await send();
    return null;
  } catch (error) {
    return hrRefusalOf(error);
  }
}
