import 'dart:async';

import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';

/// Lets a lazily-created feature cubit follow later branch selections without
/// the app shell creating that feature (and loading its data) pre-emptively.
class BranchCubitBinding {
  StreamSubscription<BranchState>? _subscription;

  void bind(BranchCubit source, Future<void> Function(String?) onChanged) {
    _subscription?.cancel();
    _subscription = source.stream.listen((state) {
      if (state.isLoading) return;
      unawaited(onChanged(state.selected?.id));
    });
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
