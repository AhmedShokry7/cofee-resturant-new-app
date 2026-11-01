import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';

part 'on_boarding_state.dart';

/// Everything the onboarding decides: which slide is showing, when the customer
/// has reached the end, and which screen comes after it.
///
/// The screen never picks a route and never writes a marker; both used to be
/// reactions the widgets took on their own.
class OnBoardingCubit extends Cubit<OnBoardingState> {
  OnBoardingCubit({this.session = const SessionRepository()})
    : pageController = PageController(initialPage: _firstPage),
          super(const OnBoardingInitial());

  /// Where the "the onboarding is done" marker is written.
  final SessionRepository session;

  /// The controller the PageView is driven by, so the buttons can step the
  /// slides without holding a second copy of the index.
  final PageController pageController;

  /// A slide move goes both ways, so it eases in as well as out; that is not
  /// the one-way arrival [MotionTokens.entranceCurve] describes.
  static const Curve _slideCurve = Curves.easeInOut;

  static const int _firstPage = 0;

  int _currentPage = _firstPage;

  /// The slide the customer is looking at. Only [changePage] writes it, because
  /// the PageView is the thing that knows where it has stopped.
  int get currentPage => _currentPage;

  /// How many slides there are to walk through.
  int get slideCount => onBoardingSlides().length;

  /// The PageView settled on a different slide.
  void changePage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    emit(OnBoardingPageChanged(currentPage: page));
  }

  /// Shows the next slide, or ends the onboarding on the last one.
  Future<void> next() async {
    if (_currentPage < slideCount - 1) {
      await pageController.nextPage(
        duration: MotionTokens.entrance,
        curve: _slideCurve,
      );
      return;
    }
    await complete();
  }

  /// Shows the previous slide. The index is not touched here: the PageView
  /// reports where it stopped, and this method only asks for the move.
  void back() {
    if (_currentPage > _firstPage) {
      pageController.previousPage(
        duration: MotionTokens.entrance,
        curve: _slideCurve,
      );
    }
  }

  /// Records that the customer is done with the onboarding, whether they
  /// reached the last slide or skipped it, and names the screen after it.
  ///
  /// The marker is confirmed, but the exit never waits for it: storage that
  /// cannot answer must not trap a customer inside a tutorial.
  Future<void> complete() async {
    final saved = await session.markOnboardingSkippedConfirmed();
    if (!saved) {
      debugPrint('[OnBoarding] completion marker could not be persisted.');
    }
    if (isClosed) return;
    emit(const OnBoardingCompleted(nextRoute: AuthPage.routeName));
  }

  @override
  Future<void> close() {
    pageController.dispose();
    return super.close();
  }
}
