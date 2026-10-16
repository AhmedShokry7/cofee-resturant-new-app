part of 'on_boarding_cubit.dart';

@immutable
sealed class OnBoardingState {
  const OnBoardingState();
}

final class OnBoardingInitial extends OnBoardingState {
  const OnBoardingInitial();
}

final class OnBoardingLoaded extends OnBoardingState {
  const OnBoardingLoaded({required this.slides});

  final List<OnBoardingModel> slides;
}

final class OnBoardingError extends OnBoardingState {
  const OnBoardingError({required this.message});

  final String message;
}

final class OnBoardingPageChanged extends OnBoardingState {
  final int currentPage;
  final List<OnBoardingModel> slides;
  const OnBoardingPageChanged({
    required this.currentPage,
    required this.slides,
  });
}
