part of 'assistant_fab_cubit.dart';

@immutable
class AssistantFabState {
  const AssistantFabState({this.firstName, this.isReturningUser = false});

  /// The signed-in customer's first name, for the chat's first line.
  final String? firstName;

  /// Whether this device already reached the Home tab in an earlier session.
  final bool isReturningUser;

  AssistantFabState copyWith({String? firstName, bool? isReturningUser}) {
    return AssistantFabState(
      firstName: firstName ?? this.firstName,
      isReturningUser: isReturningUser ?? this.isReturningUser,
    );
  }
}
