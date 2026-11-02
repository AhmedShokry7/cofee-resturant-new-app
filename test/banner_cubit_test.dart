import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/home/presentation/manager/banner/banner_cubit.dart';

/// The rules the carousel's own state runs: what a tick does, and that a page
/// reporting the index it is already on stays quiet.
///
/// The five-second timer is not driven here - [BannerCubit.next] is what it
/// calls, and that is the part that can be wrong.
void main() {
  test('advances to the next banner and wraps past the last', () {
    final cubit = BannerCubit(length: 3);
    addTearDown(cubit.close);

    expect(cubit.state.index, 0);
    cubit.next();
    expect(cubit.state.index, 1);
    cubit.next();
    cubit.next();
    expect(cubit.state.index, 0, reason: 'the strip loops instead of stopping');
  });

  test('an empty carousel never advances', () {
    final cubit = BannerCubit(length: 0);
    addTearDown(cubit.close);

    cubit.next();
    expect(
      cubit.state.index,
      0,
      reason: 'modulo zero would throw on a home page with no banners',
    );
  });

  test('a swipe back to the current page emits nothing', () async {
    final cubit = BannerCubit(length: 3);
    addTearDown(cubit.close);
    final emissions = <int>[];
    final subscription = cubit.stream.listen(
      (state) => emissions.add(state.index),
    );

    // PageView calls this after its own animation lands, reporting the index
    // the state already holds.
    cubit.jumpTo(0);
    await Future<void>.delayed(Duration.zero);
    expect(
      emissions,
      isEmpty,
      reason: 'a state that changed nothing must not rebuild the dot row',
    );

    cubit.jumpTo(2);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, [2]);

    await subscription.cancel();
  });
}
