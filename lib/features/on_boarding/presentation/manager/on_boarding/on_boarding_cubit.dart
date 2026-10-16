import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';

part 'on_boarding_state.dart';

class OnBoardingCubit extends Cubit<OnBoardingState> {
  OnBoardingCubit({required this.content}) : super(OnBoardingInitial()) {
    pageController = PageController(initialPage: currentPage);
    load();
  }

  final ContentRepository content;

  int currentPage = 0;
  late PageController pageController;

  List<OnBoardingModel> _slides = const [];

  Future<void> load() async {
    try {
      final slides = await content.onBoardingSlides();
      if (isClosed) return;
      _slides = slides;
      emit(OnBoardingLoaded(slides: slides));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(OnBoardingError(message: error.toString()));
      addError(error, stackTrace);
    }
  }

  int get slideCount => _slides.length;

  void changePage(int page) {
    currentPage = page;
    emit(OnBoardingPageChanged(currentPage: page, slides: _slides));
  }

  void nextBtn(BuildContext context) async {
    if (currentPage < slideCount - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      currentPage++;
      emit(OnBoardingPageChanged(currentPage: currentPage, slides: _slides));
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
      emit(OnBoardingPageChanged(currentPage: currentPage, slides: _slides));
    }
  }
}
