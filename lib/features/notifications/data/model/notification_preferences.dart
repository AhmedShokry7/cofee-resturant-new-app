import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/data/db_values.dart';

/// The switches the server holds for one customer.
///
/// [pushEnabled] and [emailEnabled] are the two channels, each with its own
/// gate: a phone banner and a mailbox are different promises, and a customer
/// who wants one of them is not asked for the other. The four type switches
/// decide which kinds may still go out after a channel is open, and the
/// send-push and send-email functions read them from this same row before they
/// contact FCM or Resend, so a switch written here is honoured on every device
/// and every address of the customer.
///
/// In-app rows are not filtered by any of them: the list on the notifications
/// screen stays complete whether or not a push or a mail was allowed to go out.
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = false,
    this.emailEnabled = false,
    this.orderStatus = true,
    this.promo = true,
    this.loyalty = true,
    this.system = true,
    this.chosen = false,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool orderStatus;
  final bool promo;
  final bool loyalty;
  final bool system;

  /// Whether the customer has ever chosen, as the server records it.
  ///
  /// `push_preferences()` answers a customer with no preferences row with a
  /// synthesised object whose `updated_at` is null, while a stored row always
  /// carries a timestamp. The difference is what lets the app tell "never
  /// asked" from "asked and switched off" - only the first of the two may be
  /// opened on the customer's behalf.
  final bool chosen;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        pushEnabled: Db.asBool(json['push_enabled']),
        emailEnabled: Db.asBool(json['email_enabled']),
        orderStatus: Db.asBool(json['order_status'], fallback: true),
        promo: Db.asBool(json['promo'], fallback: true),
        loyalty: Db.asBool(json['loyalty'], fallback: true),
        system: Db.asBool(json['system'], fallback: true),
        chosen: Db.textOrNull(json['updated_at']) != null,
      );

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
    bool? chosen,
  }) => NotificationPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    orderStatus: orderStatus ?? this.orderStatus,
    promo: promo ?? this.promo,
    loyalty: loyalty ?? this.loyalty,
    system: system ?? this.system,
    chosen: chosen ?? this.chosen,
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
      other.emailEnabled == emailEnabled &&
      other.orderStatus == orderStatus &&
      other.promo == promo &&
      other.loyalty == loyalty &&
      other.system == system &&
      other.chosen == chosen;

  @override
  int get hashCode => Object.hash(
    pushEnabled,
    emailEnabled,
    orderStatus,
    promo,
    loyalty,
    system,
    chosen,
  );
}

/// A type switch the customer can turn off. The two channel switches are not
/// among these: each of them gates every kind of its own channel on its own.
enum NotificationPreferenceKey { orderStatus, promo, loyalty, system }
