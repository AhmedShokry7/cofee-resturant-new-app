part of 'notifications_cubit.dart';

@immutable
class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = true,
    this.error,
    this.signedOut = false,
  });

  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final bool signedOut;

  bool get isEmpty =>
      !isLoading && error == null && !signedOut && notifications.isEmpty;

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? signedOut,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        signedOut: signedOut ?? this.signedOut,
      );
}
