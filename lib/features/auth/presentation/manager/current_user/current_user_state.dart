part of 'current_user_cubit.dart';

@immutable
class CurrentUserState {
  const CurrentUserState({this.user, this.isLoading = true});

  /// The customer the session belongs to, null while loading or signed out.
  final AuthUser? user;

  final bool isLoading;

  /// The name as the customer typed it, empty when there is nothing to show.
  String get name => user?.name?.trim() ?? '';

  CurrentUserState copyWith({
    AuthUser? user,
    bool? isLoading,
    bool clearUser = false,
  }) => CurrentUserState(
    user: clearUser ? null : (user ?? this.user),
    isLoading: isLoading ?? this.isLoading,
  );
}
