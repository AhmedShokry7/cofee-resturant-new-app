import 'package:hugeicons/hugeicons.dart';

/// فهرس أيقونات التطبيق: الاسم الدلالي هنا، والباكدج لا يُستورد في أي مكان آخر.
///
/// كل الأيقونات بنمط `strokeRounded` حتى تبقى سماكة الرسم موحدة في التطبيق.
abstract final class AppIcons {
  static const email = HugeIcons.strokeRoundedMail01;
  static const password = HugeIcons.strokeRoundedLock;
  static const passwordKey = HugeIcons.strokeRoundedKey01;
  static const eye = HugeIcons.strokeRoundedView;
  static const eyeOff = HugeIcons.strokeRoundedViewOff;
  static const alert = HugeIcons.strokeRoundedAlertCircle;
  static const server = HugeIcons.strokeRoundedCloudServer;
}
