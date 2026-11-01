import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

part 'current_user_state.dart';

/// The signed-in customer, read through the manager layer.
///
/// The home greeting and the profile page each used to start their own
/// `currentUser()` future inside a widget and rebuild with `setState`, so the
/// same row was read twice per tab and a name the customer edited only reached
/// the screen that happened to re-read it.
class CurrentUserCubit extends Cubit<CurrentUserState> {
  CurrentUserCubit({required this._repository})
    : super(const CurrentUserState());

  final AuthRepository _repository;

  /// Reads the session's customer.
  ///
  /// A read that fails leaves [CurrentUserState.user] empty rather than
  /// surfacing an error: both screens already know how to greet a customer
  /// whose name is not there, and a session that cannot be read is not
  /// something they can retry.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    AuthUser? user;
    try {
      user = await _repository.currentUser();
    } catch (_) {
      user = null;
    }
    if (isClosed) return;
    emit(state.copyWith(user: user, isLoading: false, clearUser: user == null));
  }
}
