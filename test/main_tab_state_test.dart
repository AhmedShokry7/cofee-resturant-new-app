import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';

/// Which tabs may be built used to live in a list the widget mutated inside
/// `build()`. It is state, so the cubit owns it now.
void main() {
  test('only the home tab is built before the customer taps', () {
    final cubit = MainCubit();
    addTearDown(cubit.close);

    expect(cubit.state.index, 0);
    expect(cubit.state.isBuilt(0), isTrue);
    expect(cubit.state.isBuilt(1), isFalse);
  });

  test('a visited tab stays built when the customer moves on', () {
    final cubit = MainCubit();
    addTearDown(cubit.close);

    cubit.changeTab(2);
    cubit.changeTab(4);
    cubit.changeTab(1);

    expect(cubit.state.index, 1);
    expect(
      [0, 1, 2, 3, 4].map(cubit.state.isBuilt),
      [true, true, true, false, true],
    );
  });

  test('re-selecting the current tab changes nothing', () {
    final cubit = MainCubit();
    addTearDown(cubit.close);
    cubit.changeTab(3);
    final afterFirst = cubit.state;

    cubit.changeTab(3);

    expect(identical(cubit.state, afterFirst), isTrue);
  });
}
