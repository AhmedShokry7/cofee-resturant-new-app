part of 'on_boarding_cubit.dart';

@immutable
sealed class OnBoardingState {}

final class OnBoardingInitial extends OnBoardingState {}

final class OnBoardingPageChanged extends OnBoardingState {
  final int currentPage;
  OnBoardingPageChanged({required this.currentPage});
}
