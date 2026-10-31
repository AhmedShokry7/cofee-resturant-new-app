import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/data/db_values.dart';

/// The switches the server holds for one customer.
///
/// [pushEnabled] is the master gate. The four type switches decide which kinds
/// may still be pushed after it is open, and the send-push function reads them
/// from this same row before it contacts FCM, so a switch written here is
/// honoured on every device of the customer.
///
/// In-app rows are not filtered by any of them: the list on the notifications
/// screen stays complete whether or not a push was allowed to go out.
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = false,
    this.orderStatus = true,
    this.promo = true,
    this.loyalty = true,
    this.system = true,
  });

  final bool pushEnabled;
  final bool orderStatus;
  final bool promo;
  final bool loyalty;
  final bool system;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        pushEnabled: Db.asBool(json['push_enabled']),
        orderStatus: Db.asBool(json['order_status'], fallback: true),
        promo: Db.asBool(json['promo'], fallback: true),
        loyalty: Db.asBool(json['loyalty'], fallback: true),
        system: Db.asBool(json['system'], fallback: true),
      );

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
  }) => NotificationPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    orderStatus: orderStatus ?? this.orderStatus,
    promo: promo ?? this.promo,
    loyalty: loyalty ?? this.loyalty,
    system: system ?? this.system,
  );

  bool valueOf(NotificationPreferenceKey key) => switch (key) {
    NotificationPreferenceKey.orderStatus => orderStatus,
    NotificationPreferenceKey.promo => promo,
    NotificationPreferenceKey.loyalty => loyalty,
    NotificationPreferenceKey.system => system,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.pushEnabled == pushEnabled &&
      other.orderStatus == orderStatus &&
      other.promo == promo &&
      other.loyalty == loyalty &&
      other.system == system;

  @override
  int get hashCode =>
      Object.hash(pushEnabled, orderStatus, promo, loyalty, system);
}

/// A type switch the customer can turn off. The master push switch is not one
/// of these: it gates every push on its own.
enum NotificationPreferenceKey { orderStatus, promo, loyalty, system }
