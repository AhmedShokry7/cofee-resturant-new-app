part of 'notifications_cubit.dart';

@immutable
class NotificationsState {
  const NotificationsState({this.readIds = const {}});

  final Set<String> readIds;
}
