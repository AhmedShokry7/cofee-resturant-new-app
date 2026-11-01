import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/data/repositories/push_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_preferences_sheet.dart';

/// The switches of one customer, held in memory.
///
/// [refuseWrites] stands for a write the server will not answer — no session,
/// a dropped request — and is how the tests check that a refused change does
/// not leave a switch drawn in a position the server never stored.
class _FakePushRepository implements PushRepository {
  bool pushEnabled = false;
  bool emailEnabled = false;
  bool orderStatus = true;
  bool promo = true;
  bool loyalty = true;
  bool system = true;
  bool refuseWrites = false;
  int writeCount = 0;

  NotificationPreferences get row => NotificationPreferences(
    pushEnabled: pushEnabled,
    emailEnabled: emailEnabled,
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
  }) async {}

  @override
  Future<bool> unregisterToken(String token) async => true;

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
    bool? emailEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
  }) async {
    writeCount++;
    if (refuseWrites) throw StateError('The write was refused.');
    this.pushEnabled = pushEnabled ?? this.pushEnabled;
    this.emailEnabled = emailEnabled ?? this.emailEnabled;
    this.orderStatus = orderStatus ?? this.orderStatus;
    this.promo = promo ?? this.promo;
    this.loyalty = loyalty ?? this.loyalty;
    this.system = system ?? this.system;
    return row;
  }
}

class _EmptyNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async =>
      const [];

  @override
  Future<int> markRead(List<String> ids) async => 0;
}

NotificationsCubit _cubit(_FakePushRepository push) => NotificationsCubit(
  repository: _EmptyNotificationsRepository(),
  pushRepository: push,
  // The permission of the phone is not what these tests are about, so the
  // switch answers exactly what it is asked for.
  pushSwitch: (enabled) async => enabled,
);

void main() {
  group('NotificationPreferences', () {
    test('a missing row allows every type and opens no channel', () {
      const preferences = NotificationPreferences();
      expect(preferences.pushEnabled, isFalse);
      expect(preferences.emailEnabled, isFalse);
      expect(preferences.orderStatus, isTrue);
      expect(preferences.promo, isTrue);
      expect(preferences.loyalty, isTrue);
      expect(preferences.system, isTrue);
    });

    test('the server row is read column by column', () {
      final preferences = NotificationPreferences.fromJson(
        const <String, dynamic>{
          'push_enabled': true,
          'email_enabled': true,
          'order_status': false,
          'promo': true,
          'loyalty': false,
          'system': true,
        },
      );
      expect(preferences.pushEnabled, isTrue);
      expect(preferences.emailEnabled, isTrue);
      expect(preferences.orderStatus, isFalse);
      expect(preferences.loyalty, isFalse);
      expect(preferences.valueOf(NotificationPreferenceKey.promo), isTrue);
    });

    test('a row without the type columns still allows every type', () {
      final preferences = NotificationPreferences.fromJson(
        const <String, dynamic>{'push_enabled': true},
      );
      expect(preferences.orderStatus, isTrue);
      expect(preferences.system, isTrue);
      // A row written before the mail channel existed mails nobody: the switch
      // is asked for, never assumed.
      expect(preferences.emailEnabled, isFalse);
    });
  });

  group('NotificationsCubit switches', () {
    test('every switch is read from the server', () async {
      final push = _FakePushRepository()
        ..pushEnabled = true
        ..promo = false;
      final cubit = _cubit(push);
      addTearDown(cubit.close);

      await cubit.loadPushState();

      expect(cubit.state.pushEnabled, isTrue);
      expect(cubit.state.preferences.promo, isFalse);
      expect(cubit.state.preferences.orderStatus, isTrue);
    });

    test(
      'a switch the customer moves is stored and answered from the row',
      () async {
        final push = _FakePushRepository();
        final cubit = _cubit(push);
        addTearDown(cubit.close);

        final saved = await cubit.setTypePreference(
          NotificationPreferenceKey.promo,
          false,
        );

        expect(saved, isTrue);
        expect(push.promo, isFalse);
        expect(cubit.state.preferences.promo, isFalse);
        expect(push.writeCount, 1);
      },
    );

    test('moving one switch leaves the others alone', () async {
      final push = _FakePushRepository()
        ..promo = false
        ..loyalty = false;
      final cubit = _cubit(push);
      addTearDown(cubit.close);

      await cubit.setTypePreference(
        NotificationPreferenceKey.orderStatus,
        false,
      );

      expect(push.orderStatus, isFalse);
      expect(push.promo, isFalse);
      expect(push.loyalty, isFalse);
      expect(push.pushEnabled, isFalse);
    });

    test(
      'a write the server refuses keeps the switches it already had',
      () async {
        final push = _FakePushRepository()..refuseWrites = true;
        final cubit = _cubit(push);
        addTearDown(cubit.close);
        await cubit.loadPushState();

        final saved = await cubit.setTypePreference(
          NotificationPreferenceKey.loyalty,
          false,
        );

        expect(saved, isFalse);
        expect(cubit.state.preferences.loyalty, isTrue);
        expect(push.loyalty, isTrue);
      },
    );

    test('the master switch does not disturb the type switches', () async {
      final push = _FakePushRepository()..orderStatus = false;
      final cubit = _cubit(push);
      addTearDown(cubit.close);
      await cubit.loadPushState();
      expect(cubit.state.preferences.orderStatus, isFalse);

      await cubit.setPushEnabled(true);

      expect(cubit.state.pushEnabled, isTrue);
      expect(cubit.state.preferences.orderStatus, isFalse);
    });

    test('the mail switch opens the mail channel and nothing else', () async {
      final push = _FakePushRepository()
        ..pushEnabled = true
        ..promo = false;
      final cubit = _cubit(push);
      addTearDown(cubit.close);
      await cubit.loadPushState();

      final saved = await cubit.setEmailEnabled(true);

      expect(saved, isTrue);
      expect(push.emailEnabled, isTrue);
      // The push is a separate promise: agreeing to mail does not switch the
      // phone banner on, and it does not re-open a type the customer closed.
      expect(push.pushEnabled, isTrue);
      expect(push.promo, isFalse);
      expect(cubit.state.preferences.emailEnabled, isTrue);
    });

    test(
      'a refused mail write leaves the switch where the server left it',
      () async {
        final push = _FakePushRepository()..refuseWrites = true;
        final cubit = _cubit(push);
        addTearDown(cubit.close);
        await cubit.loadPushState();

        final saved = await cubit.setEmailEnabled(true);

        expect(saved, isFalse);
        expect(push.emailEnabled, isFalse);
        expect(cubit.state.preferences.emailEnabled, isFalse);
      },
    );

    test('closing the mail channel does not close the phone one', () async {
      final push = _FakePushRepository()
        ..pushEnabled = true
        ..emailEnabled = true;
      final cubit = _cubit(push);
      addTearDown(cubit.close);
      await cubit.loadPushState();

      await cubit.setEmailEnabled(false);

      expect(cubit.state.preferences.emailEnabled, isFalse);
      expect(cubit.state.pushEnabled, isTrue);
    });

    test(
      'a customer who signs out loses the switches of the previous one',
      () async {
        final push = _FakePushRepository()..promo = false;
        final cubit = _cubit(push);
        addTearDown(cubit.close);
        cubit.applyIdentityTransition('customer-a');
        await cubit.loadPushState();
        expect(cubit.state.preferences.promo, isFalse);

        cubit.applyIdentityTransition(null);

        expect(cubit.state.preferences.promo, isTrue);
        expect(cubit.state.pushEnabled, isFalse);
      },
    );
  });

  group('preferences sheet', () {
    testWidgets(
      'the mail channel and every type switch read what the server holds',
      (tester) async {
        final push = _FakePushRepository()
          ..emailEnabled = true
          ..loyalty = false;
        final cubit = _cubit(push);
        addTearDown(cubit.close);
        await cubit.loadPushState();

        await tester.pumpWidget(_harness(cubit));
        await tester.tap(find.byKey(const Key('open-preferences')));
        await tester.pumpAndSettle();

        expect(find.byType(SwitchListTile), findsNWidgets(5));
        final rows = tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .toList();
        // The mail channel is offered first, then the types in the order of
        // NotificationPreferenceKey: order updates, offers, loyalty, messages.
        expect(rows[0].value, isTrue);
        expect(rows[1].value, isTrue);
        expect(rows[3].value, isFalse);

        // Five rows are taller than the test window, so the row that is about
        // to be tapped is brought into view first.
        await tester.ensureVisible(find.byType(SwitchListTile).at(2));
        await tester.tap(find.byType(Switch).at(2));
        await tester.pumpAndSettle();

        expect(push.promo, isFalse);
        final after = tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .toList();
        expect(after[2].value, isFalse);
      },
    );

    testWidgets('tapping the mail switch writes the mail column of the row', (
      tester,
    ) async {
      final push = _FakePushRepository();
      final cubit = _cubit(push);
      addTearDown(cubit.close);
      await cubit.loadPushState();

      await tester.pumpWidget(_harness(cubit));
      await tester.tap(find.byKey(const Key('open-preferences')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(push.writeCount, 1);
      expect(push.emailEnabled, isTrue);
      expect(push.pushEnabled, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'a switch the server refuses is drawn back where the server left it',
      (tester) async {
        final push = _FakePushRepository()..refuseWrites = true;
        final cubit = _cubit(push);
        addTearDown(cubit.close);
        await cubit.loadPushState();

        await tester.pumpWidget(_harness(cubit));
        await tester.tap(find.byKey(const Key('open-preferences')));
        await tester.pumpAndSettle();

        // The second switch is the first of the types: order updates.
        await tester.ensureVisible(find.byType(SwitchListTile).at(1));
        await tester.tap(find.byType(Switch).at(1));
        await tester.pumpAndSettle();

        expect(push.orderStatus, isTrue);
        final rows = tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .toList();
        expect(rows[1].value, isTrue);
        // The customer is told, rather than left with a switch that moved and
        // silently moved back.
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}

/// The sheet needs a customer and a scaffold to open over.
Widget _harness(NotificationsCubit cubit) => BlocProvider.value(
  value: cubit,
  child: MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const Key('open-preferences'),
          onPressed: () => showNotificationPreferencesSheet(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);
