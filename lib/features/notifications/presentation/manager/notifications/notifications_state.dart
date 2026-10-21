part of 'notifications_cubit.dart';

@immutable
class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = true,
    this.error,
    this.signedOut = false,
    this.pushEnabled = false,
  });

  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final bool signedOut;

  /// Whether the customer receives push notifications on this phone.
  ///
  /// It is a switch of the customer, not of the device, so it is the same on
  /// every phone they sign in on.
  final bool pushEnabled;

  bool get isEmpty =>
      !isLoading && error == null && !signedOut && notifications.isEmpty;

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? signedOut,
    bool? pushEnabled,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        signedOut: signedOut ?? this.signedOut,
        pushEnabled: pushEnabled ?? this.pushEnabled,
      );
}
