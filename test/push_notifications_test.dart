import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/navigation/notification_routes.dart';
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

  /// Whether the customer has ever been recorded as choosing. The server only
  /// ever sets this by itself, so a write is enough to set it here.
  bool chosen = false;

  /// Whether reading the row fails, for a test of what a device does then.
  bool unreadable = false;

  int preferenceWrites = 0;
  final List<String> registered = [];
  final List<String> removed = [];

  NotificationPreferences get row => NotificationPreferences(
    pushEnabled: pushEnabled,
    orderStatus: orderStatus,
    promo: promo,
    loyalty: loyalty,
    system: system,
    chosen: chosen,
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
  Future<NotificationPreferences> preferences() async {
    if (unreadable) throw StateError('no session');
    return row;
  }

  @override
  Future<NotificationPreferences> setPreferences({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
  }) async {
    preferenceWrites++;
    chosen = true;
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
  Future<List<NotificationModel>> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<int> markRead(List<String> ids) async => 0;

  @override
  Future<int> deleteNotifications(List<String> ids) async => 0;

  @override
  Future<int> deleteAllNotifications() async => 0;
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
    final push = _FakePushRepository();
    final cubit = NotificationsCubit(
      repository: _EmptyNotificationsRepository(),
      pushRepository: push,
      pushSwitch: (enabled) async =>
          (await push.setPreferences(pushEnabled: enabled)).pushEnabled,
    );
    addTearDown(cubit.close);

    await cubit.setPushEnabled(true);
    expect(cubit.state.pushEnabled, isTrue);

    await cubit.setPushEnabled(false);
    expect(cubit.state.pushEnabled, isFalse);
  });

  test('the service keeps the place a tapped notification opens', () {
    // An order message is kept with the id it names, because the page that
    // draws it reads its rows from that id.
    PushService.setPendingRoute(
      const NotificationOpen(
        route: 'notificationsRoute',
        entityId: '4db6e1a4-2f31-4b0a-9d2b-7c1f5e6a8b90',
      ),
    );
    final taken = PushService.takePendingRoute();
    expect(taken?.route, 'notificationsRoute');
    expect(taken?.entityId, '4db6e1a4-2f31-4b0a-9d2b-7c1f5e6a8b90');
    // The route is taken once: a second tap must not open the screen twice.
    expect(PushService.takePendingRoute(), isNull);
  });

  group('the switch of a device that already allowed notifications', () {
    test('a customer who has never chosen is opened on the server', () async {
      // The backend stops every message of a customer with no preferences row,
      // so a phone that was allowed in its own settings still received nothing.
      final push = _FakePushRepository();
      await PushService.adoptGrantedPush(push);

      expect(push.preferenceWrites, 1);
      expect(push.row.pushEnabled, isTrue);
    });

    test('a customer who answered no is left alone', () async {
      final push = _FakePushRepository()..chosen = true;
      await PushService.adoptGrantedPush(push);

      expect(push.preferenceWrites, 0);
      expect(push.row.pushEnabled, isFalse);
    });

    test('a customer already opened is not written again', () async {
      final push = _FakePushRepository()..pushEnabled = true;
      await PushService.adoptGrantedPush(push);

      expect(push.preferenceWrites, 0);
    });

    test(
      'a row that cannot be read is not an error the customer sees',
      () async {
        final push = _FakePushRepository()..unreadable = true;
        await PushService.adoptGrantedPush(push);

        expect(push.preferenceWrites, 0);
      },
    );
  });

  group('reading the switches', () {
    test('the synthesised answer is never chosen, a stored row is', () {
      expect(
        NotificationPreferences.fromJson({'push_enabled': false}).chosen,
        isFalse,
      );
      expect(
        NotificationPreferences.fromJson({
          'push_enabled': false,
          'updated_at': null,
        }).chosen,
        isFalse,
      );
      expect(
        NotificationPreferences.fromJson({
          'push_enabled': false,
          'updated_at': '2026-11-01T10:00:00+00:00',
        }).chosen,
        isTrue,
      );
    });

    test('a customer who has never chosen keeps the switch off', () async {
      final cubit = NotificationsCubit(
        repository: _EmptyNotificationsRepository(),
        pushRepository: _FakePushRepository(),
      );
      addTearDown(cubit.close);

      await cubit.loadPushState();
      expect(cubit.state.pushNeverChosen, isTrue);
      expect(cubit.state.preferencesRead, isTrue);
    });
  });
}
