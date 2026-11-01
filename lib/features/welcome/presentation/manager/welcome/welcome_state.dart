part of 'welcome_cubit.dart';

@immutable
class WelcomeState {
  /// The idle screen: the customer has not chosen anything yet.
  const WelcomeState({
    this.isStarting = false,
    this.nextRoute,
    this.saveFailed = false,
  });

  /// The marker write is in flight, so a second tap has nothing to do.
  final bool isStarting;

  /// The screen to replace this one with, offered only once the marker is
  /// confirmed. Null means stay put.
  final String? nextRoute;

  /// The marker could not be stored, so the app is not going anywhere.
  final bool saveFailed;
}
