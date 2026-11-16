import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';

/// التبويب الذي يُفتح به الهيكل يُعدّ مزارًا من اللحظة الأولى.
///
/// وضع المعاينة يفتح الهيكل على صفحة التصنيفات (initialTab = 1)؛ لو لم
/// تُعدّ مزارة فترسم خانة فارغة والشريط يُبرز تبويبًا لا محتوى له — وهي
/// الشاشة البيضاء التي ظهرت في محاكي المحرّر المرئي.
void main() {
  test('the tab the shell opens on is already built', () {
    MainCubit.initialTab = 1;
    final cubit = MainCubit();
    expect(cubit.state.index, 1);
    expect(cubit.state.isBuilt(1), isTrue);
  });

  test('production opens on the home tab as before', () {
    MainCubit.initialTab = 0;
    final cubit = MainCubit();
    expect(cubit.state.index, 0);
    expect(cubit.state.isBuilt(0), isTrue);
    expect(cubit.state.isBuilt(2), isFalse);
  });
}
