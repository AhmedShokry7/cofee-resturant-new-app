import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة سطح واحد: قائمة، وحالة تحميل، وآخر كتابة وما ردّت به القاعدة.
///
/// القائمة تُترك `[]` عند الفراغ الحقيقي وحده؛ والفشل يبقي `status` على
/// `failure` مع رفضه، فلا تُقرأ شاشة لم تُحمَّل يومًا صفرًا.
class HrListState<T> {
  const HrListState({
    this.status = HrLoadStatus.initial,
    this.items = const <Never>[],
    this.failure,
    this.writing = HrWriteStatus.idle,
    this.receipt,
  });

  final HrLoadStatus status;
  final List<T> items;

  /// رفض آخر قراءة أو آخر كتابة، بحروف قاعدتها.
  final HrRefusal? failure;

  final HrWriteStatus writing;

  /// إيصال آخر كتابة: معرّف السطر وحالته، وأرقامها إن أعطت الدالة بعضها.
  /// `null` ما لم تُكتب شيئًا في هذه الجلسة.
  final HrReceipt? receipt;

  bool get isLoading => status == HrLoadStatus.loading;
  bool get isReady => status == HrLoadStatus.ready;
  bool get isWriting => writing == HrWriteStatus.sending;
  bool get hasItems => items.isNotEmpty;

  HrListState<T> copyWith({
    HrLoadStatus? status,
    List<T>? items,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
    HrReceipt? receipt,
  }) => HrListState<T>(
    status: status ?? this.status,
    items: items ?? this.items,
    failure: clearFailure ? null : (failure ?? this.failure),
    writing: writing ?? this.writing,
    receipt: receipt ?? this.receipt,
  );
}
