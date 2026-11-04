import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/data/repositories/push_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_day_header.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_push_banner.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// Counts every repository round trip so a test can tell a bounded read from an
/// endless one, and answers a page the way the server does.
class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({
    List<NotificationModel>? rows,
    this.signedOut = false,
  }) : rows = rows ?? const [];

  List<NotificationModel> rows;
  bool signedOut;

  int listCalls = 0;
  int markReadCalls = 0;
  final List<List<String>> markedIds = [];

  @override
  Future<List<NotificationModel>> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls++;
    if (signedOut) throw const NotificationSignInRequiredException();
    if (offset >= rows.length) return const [];
    return rows.sublist(offset, (offset + limit).clamp(0, rows.length));
  }

  /// Only the ids handed over are written, exactly as the server RPC does, so a
  /// test can tell "this row was read" from "the whole list was cleared".
  @override
  Future<int> markRead(List<String> ids) async {
    markReadCalls++;
    markedIds.add(List<String>.of(ids));
    rows = [for (final row in rows) ids.contains(row.id) ? _asRead(row) : row];
    return ids.length;
  }

  static NotificationModel _asRead(NotificationModel row) => NotificationModel(
    id: row.id,
    titleAr: row.titleAr,
    titleEn: row.titleEn,
    bodyAr: row.bodyAr,
    bodyEn: row.bodyEn,
    type: row.type,
    imageUrl: row.imageUrl,
    destination: row.destination,
    createdAt: row.createdAt,
    isRead: true,
  );
}

/// The switches of the customer, with a memory of what was written.
class _FakePushRepository implements PushRepository {
  _FakePushRepository({this.row = const NotificationPreferences()});

  NotificationPreferences row;

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
    row = row.copyWith(
      pushEnabled: pushEnabled,
      emailEnabled: emailEnabled,
      orderStatus: orderStatus,
      promo: promo,
      loyalty: loyalty,
      system: system,
    );
    return row;
  }

  @override
  Future<bool> setPushEnabled(bool enabled) async {
    row = row.copyWith(pushEnabled: enabled);
    return enabled;
  }

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
}

/// Noon of the day `daysAgo` counts back from today.
///
/// The hour matters: a row dated by `DateTime.now()` would move between two
/// blocks when the suite runs just after midnight, so the fixtures sit in the
/// middle of their day.
DateTime _dayNoon(int daysAgo) {
  final today = DateTime.now();
  return DateTime(
    today.year,
    today.month,
    today.day,
    12,
  ).subtract(Duration(days: daysAgo));
}

NotificationModel _row(
  String id, {
  bool isRead = false,
  String? imageUrl,
  DateTime? createdAt,
  int daysAgo = 0,
  bool withoutTime = false,
}) => NotificationModel(
  id: id,
  titleAr: 'عنوان',
  titleEn: 'Title $id',
  bodyAr: 'نص',
  bodyEn: 'Body $id',
  type: 'order_status',
  imageUrl: imageUrl,
  // `createdAt: null` cannot mean "no time" on its own, because the helper
  // would fill in a day; the flag says it outright.
  createdAt: withoutTime ? null : (createdAt ?? _dayNoon(daysAgo)),
  isRead: isRead,
);

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, NotificationsCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        OrdersPage.routeName: (_) => const Scaffold(body: Text('orders')),
      },
      home: BlocProvider.value(value: cubit, child: const NotificationsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// A cubit over the given rows.
///
/// The switches are handed as "already chosen" unless a test says otherwise, so
/// the push banner stays out of the way of the list assertions.
NotificationsCubit _cubit(
  _FakeNotificationsRepository repository, {
  _FakePushRepository? push,
}) {
  final cubit = NotificationsCubit(
    repository: repository,
    pushRepository:
        push ??
        _FakePushRepository(
          row: const NotificationPreferences(chosen: true, pushEnabled: true),
        ),
    pushSwitch: (enabled) async => enabled,
  );
  addTearDown(cubit.close);
  return cubit;
}

/// Frames to push through while the page stays open. Every one of them used to
/// re-enter the builder and schedule another mark-as-read.
const _idleFrames = 40;

void main() {
  group('opening the page reads, and marks nothing', () {
    testWidgets('staying open reads once and writes nothing', (tester) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [_row('n1'), _row('n2')],
      );
      final cubit = _cubit(repository);

      await _pumpPage(tester, cubit);

      expect(repository.listCalls, 1, reason: 'a visit is a read, not a write');
      expect(repository.markReadCalls, 0);
      expect(cubit.unreadCount, 2);

      for (var i = 0; i < _idleFrames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        repository.listCalls,
        1,
        reason: 'no state emission may restart a mark-as-read cycle',
      );
      expect(repository.markReadCalls, 0);
    });

    testWidgets('the tap of a row marks that row and opens its page', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [_row('n1'), _row('n2')],
      );
      final cubit = _cubit(repository);

      await _pumpPage(tester, cubit);
      await tester.tap(find.byType(NotificationTile).first);
      await tester.pumpAndSettle();

      expect(find.text('orders'), findsOneWidget);
      expect(repository.markedIds.single, ['n1']);
      expect(cubit.state.notifications.first.isRead, isTrue);
      expect(cubit.state.notifications.last.isRead, isFalse);
      expect(cubit.unreadCount, 1);
    });

    testWidgets('the app bar offers mark-all only while something waits', (
      tester,
    ) async {
      await _setSurface(tester);
      final unread = _FakeNotificationsRepository(
        rows: [_row('n1'), _row('n2')],
      );
      await _pumpPage(tester, _cubit(unread));
      expect(
        find.byKey(const ValueKey('notification-mark-all')),
        findsOneWidget,
      );

      await _setSurface(tester);
      final read = _FakeNotificationsRepository(
        rows: [_row('n1', isRead: true)],
      );
      await _pumpPage(tester, _cubit(read));
      expect(find.byKey(const ValueKey('notification-mark-all')), findsNothing);
    });

    testWidgets('mark-all writes every row still waiting', (tester) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [_row('n1'), _row('n2'), _row('n3', isRead: true)],
      );
      final cubit = _cubit(repository);

      await _pumpPage(tester, cubit);
      await tester.tap(find.byKey(const ValueKey('notification-mark-all')));
      await tester.pumpAndSettle();

      expect(repository.markedIds.single, ['n1', 'n2']);
      expect(cubit.unreadCount, 0);
      expect(find.byKey(const ValueKey('notification-mark-all')), findsNothing);
    });

    testWidgets('a signed-out repository settles instead of retrying', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(signedOut: true);
      final cubit = _cubit(repository);

      await _pumpPage(tester, cubit);
      for (var i = 0; i < _idleFrames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repository.listCalls, 1);
      expect(cubit.state.signedOut, isTrue);
      expect(cubit.state.notifications, isEmpty);
    });
  });

  group('marking current rows is separate from later ones', () {
    test('only the ids unread at call time are written', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('n1')]);
      final cubit = _cubit(repository);
      await cubit.stream.firstWhere((state) => !state.isLoading);

      await cubit.markAllRead();
      expect(repository.markedIds.single, ['n1']);

      // A row arriving after that visit is untouched by it.
      repository.rows = [_row('n1', isRead: true), _row('n2')];
      await cubit.refresh();
      expect(cubit.unreadCount, 1);

      await cubit.markAllRead();
      expect(repository.markedIds.last, ['n2']);
      expect(cubit.unreadCount, 0);
    });

    test('nothing unread means no write at all', () async {
      final repository = _FakeNotificationsRepository(
        rows: [_row('n1', isRead: true)],
      );
      final cubit = _cubit(repository);
      await cubit.stream.firstWhere((state) => !state.isLoading);

      await cubit.markAllRead();
      expect(repository.markReadCalls, 0);
      expect(repository.markedIds, isEmpty);
    });
  });

  group('the day a row belongs to', () {
    test('the two nearest days are named, the rest are dated', () {
      final now = DateTime(2026, 11, 4, 18);
      expect(notificationDayLabel(DateTime(2026, 11, 4), now: now), 'اليوم');
      expect(notificationDayLabel(DateTime(2026, 11, 3), now: now), 'أمس');
      expect(notificationDayLabel(DateTime(2026, 11, 1), now: now), '1/11');
      expect(
        notificationDayLabel(DateTime(2025, 11, 1), now: now),
        '1/11/2025',
      );
    });

    test(
      'a row is grouped by its calendar day, not by the last twenty-four hours',
      () {
        final today = DateTime.now();
        final justAfterMidnight = DateTime(
          today.year,
          today.month,
          today.day,
          0,
          30,
        );
        expect(
          deliveryDayOf(_row('late', createdAt: justAfterMidnight)),
          DateTime(today.year, today.month, today.day),
        );
        expect(
          deliveryDayOf(
            _row(
              'earlier',
              createdAt: justAfterMidnight.subtract(const Duration(hours: 1)),
            ),
          ),
          DateTime(today.year, today.month, today.day - 1),
        );
        expect(deliveryDayOf(_row('undated', withoutTime: true)), isNull);
      },
    );

    testWidgets('the list is cut into blocks by day', (tester) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [
          _row('today'),
          _row('yesterday-a', daysAgo: 1),
          _row('yesterday-b', daysAgo: 1),
        ],
      );
      await _pumpPage(tester, _cubit(repository));

      final headers = find.byType(NotificationDayHeader);
      expect(headers, findsNWidgets(2));
      expect(
        tester.widget<NotificationDayHeader>(headers.first).label,
        'اليوم',
      );
      expect(tester.widget<NotificationDayHeader>(headers.last).label, 'أمس');
    });

    testWidgets('a row without a time is drawn without a heading', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [_row('dated'), _row('undated', withoutTime: true)],
      );
      await _pumpPage(tester, _cubit(repository));

      expect(find.byType(NotificationTile), findsNWidgets(2));
      expect(find.byType(NotificationDayHeader), findsOneWidget);
    });
  });

  group('the rows beyond the first page', () {
    testWidgets('the ask for more reads the next page and appends it', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [
          for (var i = 0; i < NotificationsCubit.pageSize + 5; i++) _row('n$i'),
        ],
      );
      final cubit = _cubit(repository);

      await _pumpPage(tester, cubit);
      expect(cubit.state.notifications.length, NotificationsCubit.pageSize);
      expect(cubit.state.hasMore, isTrue);

      // A whole page of rows is drawn before it, so the ask has to be brought
      // on screen before it can be found or tapped.
      final showMore = find.byKey(const ValueKey('notification-show-more'));
      await tester.scrollUntilVisible(showMore, 300);
      await tester.pumpAndSettle();
      expect(showMore, findsOneWidget);

      await tester.tap(showMore);
      await tester.pumpAndSettle();

      expect(cubit.state.notifications.length, NotificationsCubit.pageSize + 5);
      expect(cubit.state.hasMore, isFalse);
      expect(
        find.byKey(const ValueKey('notification-show-more')),
        findsNothing,
      );
    });

    test('a page that fills exactly leaves nothing to ask for', () async {
      final repository = _FakeNotificationsRepository(
        rows: [
          for (var i = 0; i < NotificationsCubit.pageSize; i++)
            _row('n$i', isRead: true),
        ],
      );
      final cubit = _cubit(repository);
      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(cubit.state.hasMore, isFalse);
      expect(repository.listCalls, 1);
    });
  });

  group('the offer to open the phone channel', () {
    testWidgets('a customer who never chose is asked once, on the page', (
      tester,
    ) async {
      await _setSurface(tester);
      final cubit = _cubit(
        _FakeNotificationsRepository(rows: [_row('n1')]),
        push: _FakePushRepository(),
      );

      await _pumpPage(tester, cubit);
      expect(find.byType(NotificationPushBanner), findsOneWidget);

      await tester.tap(find.byType(NotificationPushBanner));
      await tester.pumpAndSettle();

      expect(cubit.state.pushEnabled, isTrue);
      expect(find.byType(NotificationPushBanner), findsNothing);
    });

    testWidgets('a customer who already answered is not asked again', (
      tester,
    ) async {
      await _setSurface(tester);
      final cubit = _cubit(
        _FakeNotificationsRepository(rows: [_row('n1')]),
        push: _FakePushRepository(
          row: const NotificationPreferences(chosen: true),
        ),
      );

      await _pumpPage(tester, cubit);
      expect(find.byType(NotificationPushBanner), findsNothing);
    });
  });

  group('the square at the head of a tile', () {
    Future<void> pumpTiles(WidgetTester tester, {String? imageUrl}) async {
      await _setSurface(tester);
      final row = _row('n1', imageUrl: imageUrl);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // The same message twice: once still waiting, once already
                // read, so the two drawings can be compared.
                NotificationTile(
                  notification: row,
                  isRead: false,
                  onTap: () {},
                ),
                NotificationTile(notification: row, onTap: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a plain message keeps the icon of its type', (tester) async {
      await pumpTiles(tester);

      expect(find.byType(DbImage), findsNothing);
      // One square for the row still waiting, one for the row already read.
      expect(find.byIcon(AppIcons.deliveryTruck), findsNWidgets(2));
    });

    testWidgets('a campaign picture replaces the icon', (tester) async {
      const url =
          'https://example.supabase.co/storage/v1/object/public/product-images/products/notifications/a.png';
      await pumpTiles(tester, imageUrl: url);

      final image = tester.widget<DbImage>(
        find.byKey(const ValueKey('notification-tile-image')).first,
      );
      expect(image.image, url);
      expect(image.width, greaterThan(0));
      expect(image.height, image.width);
    });

    testWidgets('the row still waiting is drawn on the brand tint', (
      tester,
    ) async {
      await pumpTiles(tester);

      final surfaces = find.descendant(
        of: find.byType(NotificationTile),
        matching: find.byType(Material),
      );
      expect(
        tester.widget<Material>(surfaces.first).color,
        AppColor.primarySoft,
      );
      expect(
        tester.widget<Material>(surfaces.last).color,
        AppColor.cardSurface,
      );
    });
  });

  group('notifications cubit initialises exactly once', () {
    test('the constructor is the only initial read', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('n1')]);
      final cubit = _cubit(repository);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(repository.listCalls, 1);

      await cubit.refresh();
      expect(repository.listCalls, 2);
    });

    test('concurrent reads are serialised, never interleaved', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('n1')]);
      final cubit = _cubit(repository);

      await Future.wait([cubit.load(), cubit.markAllRead(), cubit.refresh()]);
      // The constructor read, then the three queued reads, plus the read-back
      // that follows the single write.
      expect(repository.listCalls, 5);
      expect(repository.markReadCalls, 1);
    });
  });
}
