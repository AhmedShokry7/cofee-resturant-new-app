part of 'on_boarding_cubit.dart';

@immutable
sealed class OnBoardingState {
  const OnBoardingState();
}

/// The first slide, before the customer has moved anywhere.
final class OnBoardingInitial extends OnBoardingState {
  const OnBoardingInitial();
}

/// The customer is looking at [currentPage].
final class OnBoardingPageChanged extends OnBoardingState {
  const OnBoardingPageChanged({required this.currentPage});

  final int currentPage;
}

/// The onboarding is over - the last slide or a skip - and the marker has been
/// written. [nextRoute] is the screen the customer is handed to.
final class OnBoardingCompleted extends OnBoardingState {
  const OnBoardingCompleted({required this.nextRoute});

  final String nextRoute;
}
