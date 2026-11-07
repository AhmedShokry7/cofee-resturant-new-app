import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/home/data/greeting.dart';

part 'assistant_fab_state.dart';

/// Decides who the customer is when the chat opens.
///
/// The button used to speak first: a welcome bubble, then a rotation of generic
/// hints. That is a suggestion the customer never asked for, so it is gone — the
/// assistant talks when it is opened, not before. What stays here is the data
/// the chat needs for its first line: whether this device already reached Home,
/// and the signed-in customer's name.
class AssistantFabCubit extends Cubit<AssistantFabState> {
  AssistantFabCubit({this.auth}) : super(const AssistantFabState());

  /// Null when the host has no signed-in customer to greet.
  final AuthRepository? auth;

  /// Reads the saved session and the signed-in name before the button is used.
  Future<void> start() async {
    try {
      final saved = await SharedPref.getValue(key: AppConstant.routesKey);
      String? firstName;
      try {
        final user = await auth?.currentUser();
        firstName = firstNameOf(user?.name);
      } catch (_) {
        firstName = null;
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          isReturningUser: saved == AppConstant.homeRoute,
          firstName: firstName,
        ),
      );
    } catch (_) {
      // Guests and offline callers simply get the unnamed greeting.
    }
  }
}
