part of 'notifications_cubit.dart';

@immutable
class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = true,
    this.error,
    this.signedOut = false,
    this.preferences = const NotificationPreferences(),
    this.hasMore = false,
    this.isLoadingMore = false,
    this.preferencesRead = false,
  });

  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final bool signedOut;

  /// Every push switch of the customer, as the server holds it.
  final NotificationPreferences preferences;

  /// Whether the server still holds rows beyond [notifications].
  final bool hasMore;

  /// Whether the rows after [notifications] are being read.
  final bool isLoadingMore;

  /// Whether the switches of this customer have been read from the server.
  ///
  /// The screen withholds the push banner until then: the starting value of the
  /// switches is "off, never chosen", which would offer the banner to a customer
  /// who already turned the phone channel on.
  final bool preferencesRead;

  /// Whether any row on screen still waits for the customer.
  int get unreadCount => notifications.where((item) => !item.isRead).length;

  /// Whether the customer receives push notifications on this phone.
  ///
  /// It is a switch of the customer, not of the device, so it is the same on
  /// every phone they sign in on.
  bool get pushEnabled => preferences.pushEnabled;

  /// Whether the customer has ever answered the notification question.
  ///
  /// A silent device is not the same as a refused one: the screen may offer the
  /// switch, but it must not tell the customer they said no when they never did.
  bool get pushNeverChosen => !preferences.chosen;

  bool get isEmpty =>
      !isLoading && error == null && !signedOut && notifications.isEmpty;

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? signedOut,
    NotificationPreferences? preferences,
    bool? pushEnabled,
    List<NotificationModel>? more,
    bool? hasMore,
    bool? isLoadingMore,
    bool? preferencesRead,
  }) {
    final switches = preferences ?? this.preferences;
    return NotificationsState(
      notifications: more == null
          ? (notifications ?? this.notifications)
          : [...this.notifications, ...more],
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      signedOut: signedOut ?? this.signedOut,
      preferences: pushEnabled == null
          ? switches
          : switches.copyWith(pushEnabled: pushEnabled),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      preferencesRead: preferencesRead ?? this.preferencesRead,
    );
  }
}
