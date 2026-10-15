import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_knowledge.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

part 'on_boarding_state.dart';

class OnBoardingCubit extends Cubit<OnBoardingState> {
  OnBoardingCubit()
      : super(OnBoardingInitial()) {
    pageController = PageController(initialPage: currentPage);
    load();
  }

  int currentPage = 0;
  late PageController pageController;

  void load() {
    final effectiveSlides = onBoardingSlides;
    emit(OnBoardingLoaded(slides: effectiveSlides));
  }

  int get slideCount => state is OnBoardingLoaded
      ? (state as OnBoardingLoaded).slides.length
      : 0;

  void changePage(int page) {
    currentPage = page;
    emit(OnBoardingPageChanged(currentPage: page));
  }

  void nextBtn(BuildContext context) async {
    if (currentPage < slideCount - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      currentPage++;
      emit(OnBoardingPageChanged(currentPage: currentPage));
    } else {
      await SharedPref.setValue(
        key: AppConstant.routesKey,
        value: AppConstant.authRoute,
      );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(AuthPage.routeName);
    }
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