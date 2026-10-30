import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// أساس أسطح القوائم: دورة تحميل واحدة، ومسار كتابة واحد، ولا منطق عمل هنا.
///
/// الفرق بين سطح وآخر هو فقط من أين تأتي الصفوف، لذلك يتركه الأساس للدالة
/// [fetch] وحدها. القراءة والكتابة تمرّان بهذا المسار فلا يختلف سلوك شاشة عن
/// أخرى في «صفر أم فشل»، ولا تنسى شاشة أن تُعيد قراءة أرقامها بعد سطر كُتب.
abstract class HrDirectoryCubit<T> extends Cubit<HrListState<T>> {
  HrDirectoryCubit() : super(HrListState<T>());

  /// صفوف هذا السطح كما تُرجعها مستودعات HR؛ تُستدعى عند كل تحميل وبعد كل كتابة.
  Future<List<T>> fetch();

  Future<void> reload() async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          items: await fetch(),
          clearFailure: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: HrLoadStatus.failure,
          failure: hrRefusalOf(error),
        ),
      );
    }
  }

  /// كتابة واحدة ثم إعادة قراءة: الأرقام التي ترجع بعد السطر تحسبها القاعدة،
  /// فلا تُصلَح القائمة محليًا بتخمين ما صار إليه الرصيد أو الإجمالي.
  ///
  /// تُرجع false حين رُفضت الكتابة، لتبقي الشاشةُ الديالوغَ مفتوحًا بنصّ الرفض.
  /// والدوال التي ترجع سطرًا كاملًا بدل إيصال (كفرق الصناديق) تمرّ من هنا نفسها:
  /// ما ليس إيصالًا لا يُخزَّن، وتأتي صفّته من [reload].
  Future<bool> submit(Future<Object?> Function() write) async {
    if (state.isWriting) return false;
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    HrRefusal? failure;
    HrReceipt? receipt;
    try {
      final result = await write();
      if (result is HrReceipt) receipt = result;
    } catch (error) {
      failure = hrRefusalOf(error);
    }
    if (isClosed) return failure == null;
    emit(
      state.copyWith(
        writing: HrWriteStatus.done,
        receipt: receipt,
        failure: failure,
        clearFailure: failure == null,
      ),
    );
    if (failure == null) await reload();
    return failure == null;
  }
}
