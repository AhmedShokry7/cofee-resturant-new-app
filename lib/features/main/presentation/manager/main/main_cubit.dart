import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'main_state.dart';

/// The tabs of the shell, in the order the bar shows them.
///
/// The enum is the order, so a screen that wants to land somewhere names the
/// place instead of counting: the home page switched to the catalogue by writing
/// `changeTab(1)`, which became the wrong tab the moment the bar was reordered.
/// [buildMainTabs] builds its pages in this same order, and adding a case there
/// does not compile until the new tab is written down here too.
enum MainTab { home, categories, cart, favorites, settings }

class MainCubit extends Cubit<MainState> {
  /// التبويبة التي تُفتح بها الصفحة الرئيسية عند إنشائها.
  ///
  /// وضع المعاينة (main_preview.dart) يضبطها قبل دفع MainRoute ليفتح إطار
  /// المعاينة على الصفحة التي طلبها المحرّر. الإنتاج لا يلمسها: تبقى 0،
  /// وهي الرئيسية كما اليوم.
  static int initialTab = 0;

  MainCubit() : super(MainState(index: initialTab));

  void changeTab(int index) {
    if (index == state.index) return;
    emit(state.withTab(index));
  }
}
