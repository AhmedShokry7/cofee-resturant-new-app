import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
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

  Future<void> nextBtn(BuildContext context) async {
    final list = getOnBoardingList(context);
    if (currentPage < list.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    // Confirmed write, so the onboarding really is done once the app leaves
    // this screen.
    final saved = await const SessionRepository().markOnboardingSkippedConfirmed();
    if (!saved) {
      debugPrint('[OnBoarding] completion marker could not be persisted.');
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(AuthPage.routeName);
  }

  void backBtn() {
    if (currentPage > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      currentPage--;
      emit(OnBoardingPageChanged(currentPage: currentPage));
    }
  }
}
