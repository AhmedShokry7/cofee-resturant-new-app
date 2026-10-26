import 'package:admin_app/core/error/failure.dart';

/// نتيجة عملية: إما قيمة ناجحة أو [Failure].
///
/// استُخدمت بدل حزمة Either حتى تبقى التبعيات كما هي، ولأن [fold] هو كل ما
/// تحتاجه الطبقات العليا.
sealed class Result<T> {
  const Result();

  /// يشغّل أحد الجانبين فقط حسب النتيجة.
  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  );
}

/// العملية نجحت وحملت القيمة.
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  ) => onSuccess(value);
}

/// العملية فشلت وحملت السبب.
final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);

  final Failure failure;

  @override
  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  ) => onFailure(failure);
}
