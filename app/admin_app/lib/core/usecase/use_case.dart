import 'package:admin_app/core/result/result.dart';

/// عقد حالة استخدام واحدة: مدخل واحد ونتيجة واحدة.
///
/// الـ Cubit/Bloc ينادي هذه الحالات فقط ولا يعرف شيئًا عن مصدر البيانات.
abstract interface class UseCase<Output, Input> {
  Future<Result<Output>> call(Input input);
}

/// مدخل فارغ لحالات الاستخدام التي لا تحتاج معطيات.
final class NoParams {
  const NoParams();
}
