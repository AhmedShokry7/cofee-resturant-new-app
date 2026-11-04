import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/design/data/design_applier.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';

/// يقرأ التصميم المنشور ويرسمه على رموز الألوان.
///
/// القراءة لا تُرمى عند أول عطل: المستودع يجيب بآخر طبعة صالحة عرفها الهاتف، أو
/// بلا جواب حين لم يعرف واحدة. عند بلا جواب يُترك ما على الشاشة من شكل — لأن
/// إقلاعًا طبّق منشورًا ثم انقطعت الشبكة في تحديث لا يعود بالتطبيق إلى الأصل.
class DesignCubit extends Cubit<DesignState> {
  DesignCubit({required this._repository})
    : super(const DesignState()) {
    load();
  }

  final DesignRepository _repository;

  Future<void> load({bool forceRefresh = false}) async {
    final design = await _repository.published(forceRefresh: forceRefresh);
    if (isClosed || design == null) return;
    applyPublishedTheme(design.theme);
    if (design == state.design) {
      if (!state.isLoaded) emit(state.copyWith(isLoaded: true));
      return;
    }
    emit(DesignState(design: design, isLoaded: true));
  }
}
