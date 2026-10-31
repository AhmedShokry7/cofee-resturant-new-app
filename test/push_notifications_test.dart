import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/data/repositories/push_repository.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';

/// A push repository that answers from memory.
class _FakePushRepository implements PushRepository {
  bool pushEnabled = false;
  bool orderStatus = true;
  bool promo = true;
  bool loyalty = true;
  bool system = true;
  final List<String> registered = [];
  final List<String> removed = [];

  NotificationPreferences get row => NotificationPreferences(
    pushEnabled: pushEnabled,
    orderStatus: orderStatus,
    promo: promo,
    loyalty: loyalty,
    system: system,
  );

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appVersion,
    String? deviceName,
    String? locale,
  }) async {
    registered.add(token);
  }

  @override
  Future<bool> unregisterToken(String token) async {
    removed.add(token);
    return true;
  }

  @override
  Future<bool> setPushEnabled(bool enabled) async {
    pushEnabled = enabled;
    return enabled;
  }

  @override
  Future<NotificationPreferences> preferences() async => row;

  @override
  Future<NotificationPreferences> setPreferences({
    bool? pushEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
  }) async {
    this.pushEnabled = pushEnabled ?? this.pushEnabled;
    this.orderStatus = orderStatus ?? this.orderStatus;
    this.promo = promo ?? this.promo;
    this.loyalty = loyalty ?? this.loyalty;
    this.system = system ?? this.system;
    return row;
  }
}

/// A notifications repository that always answers with an empty list.
class _EmptyNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async =>
      const [];

  @override
  Future<int> markRead(List<String> ids) async => 0;
}

/// The push lives on the server: the token of the device and the switch of
/// the customer. Without a backend or without a session there is nothing to
/// store, and the repository must fail closed instead of pretending.
void main() {
  test('without a backend the token cannot be registered', () async {
    const repository = PushRepositoryImpl();
    await expectLater(
      repository.registerToken(token: 'token-123456', platform: 'android'),
      throwsA(isA<StateError>()),
    );
  });

  test('without a backend the token cannot be removed', () async {
    const repository = PushRepositoryImpl();
    await expectLater(
      repository.unregisterToken('token-123456'),
      throwsA(isA<StateError>()),
    );
  });

  test('the switch of the customer is read from the server', () async {
    final pushRepository = _FakePushRepository()..pushEnabled = true;
    final cubit = NotificationsCubit(
      repository: _EmptyNotificationsRepository(),
      pushRepository: pushRepository,
    );
    addTearDown(cubit.close);

    await cubit.loadPushState();
    expect(cubit.state.pushEnabled, isTrue);
  });

  test('a customer who is not signed in has the switch off', () async {
    final cubit = NotificationsCubit(
      repository: _EmptyNotificationsRepository(),
      pushRepository: _FakePushRepository(),
    );
    addTearDown(cubit.close);

    await cubit.loadPushState();
    expect(cubit.state.pushEnabled, isFalse);
  });

  test('turning the push off is answered by the switch', () async {
    final cubit = NotificationsCubit(
      repository: _EmptyNotificationsRepository(),
      pushRepository: _FakePushRepository(),
      pushSwitch: (enabled) async => enabled,
    );
    addTearDown(cubit.close);

    await cubit.setPushEnabled(true);
    expect(cubit.state.pushEnabled, isTrue);

    await cubit.setPushEnabled(false);
    expect(cubit.state.pushEnabled, isFalse);
  });

  test('the service keeps the route of a tapped notification', () {
    PushService.setPendingRoute('notificationsRoute');
    expect(PushService.takePendingRoute(), 'notificationsRoute');
    // The route is taken once: a second tap must not open the screen twice.
    expect(PushService.takePendingRoute(), isNull);
  });
}
