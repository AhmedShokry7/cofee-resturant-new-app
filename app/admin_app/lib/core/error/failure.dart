import 'package:equatable/equatable.dart';

/// سبب فشل عملية في طبقة البيانات.
///
/// لا يحمل نصوصًا جاهزة للواجهة: الشاشة هي التي تترجم النوع إلى رسالة،
/// حتى يبقى الفشل واحدًا مهما اختلفت اللغة أو موضع العرض.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const <Object?>[];
}

/// البريد أو كلمة المرور غير صحيحة.
final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure();
}

/// الحساب موجود لكنه ليس موظفًا نشطًا.
final class NotActiveStaffFailure extends Failure {
  const NotActiveStaffFailure();
}

/// إعدادات Supabase العامة ناقصة، فلا يمكن الاتصال أصلًا.
final class ConfigurationFailure extends Failure {
  const ConfigurationFailure();
}

/// فشل غير متوقع. الرسالة الوصفية اختيارية ولا تُعرض للمستخدم.
final class UnknownFailure extends Failure {
  const UnknownFailure([this.detail]);

  final String? detail;

  @override
  List<Object?> get props => <Object?>[detail];
}
