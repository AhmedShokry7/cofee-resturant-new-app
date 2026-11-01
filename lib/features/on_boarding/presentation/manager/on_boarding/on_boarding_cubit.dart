import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';

part 'on_boarding_state.dart';

class OnBoardingCubit extends Cubit<OnBoardingState> {
  OnBoardingCubit() : super(OnBoardingInitial()) {
    pageController = PageController(initialPage: currentPage);
  }

  int currentPage = 0;
  late PageController pageController;

  void changePage(int page) {
    currentPage = page;
    emit(OnBoardingPageChanged(currentPage: page));
  }

  /// Shows the next slide, or ends the onboarding on the last one.
  ///
  /// The cubit never navigates: it emits [OnBoardingCompleted] and the page
  /// decides where the customer goes next.
  Future<void> next() async {
    if (currentPage < onBoardingSlides().length - 1) {
      await pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    await complete();
  }

  void back() {
    if (currentPage > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      currentPage--;
      emit(OnBoardingPageChanged(currentPage: currentPage));
    }
  }

  /// Records that the customer is done with the onboarding, whether they
  /// reached the last slide or skipped it.
  Future<void> complete() async {
    // Confirmed write, so the onboarding really is done once the app leaves
    // this screen.
    final saved = await const SessionRepository()
        .markOnboardingSkippedConfirmed();
    if (!saved) {
      debugPrint('[OnBoarding] completion marker could not be persisted.');
    }
    if (isClosed) return;
    emit(OnBoardingCompleted());
  }
}
