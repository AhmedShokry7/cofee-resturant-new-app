import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';

part 'welcome_state.dart';

/// Everything the welcome screen decides: what a tap does, whether that tap is
/// still in flight, and which screen comes next.
///
/// The tap used to live in the button's `onPressed`, so the rule about writing
/// the marker before navigating could only be proven by pumping a widget, and
/// nothing told the customer when the write failed.
class WelcomeCubit extends Cubit<WelcomeState> {
  WelcomeCubit({this.session = const SessionRepository()})
    : super(const WelcomeState());

  final SessionRepository session;

  /// The customer chose to begin.
  ///
  /// The marker is written and confirmed *before* the next screen is offered: a
  /// write still in flight when the app is killed would meet the customer with
  /// the welcome screen again on the next launch.
  Future<void> startOnboarding() async {
    if (state.isStarting) return;
    emit(const WelcomeState(isStarting: true));
    final saved = await session.markOnboardingSeenConfirmed();
    if (isClosed) return;
    emit(
      saved
          ? const WelcomeState(nextRoute: OnBoardingView.routeName)
          : const WelcomeState(saveFailed: true),
    );
  }
}
