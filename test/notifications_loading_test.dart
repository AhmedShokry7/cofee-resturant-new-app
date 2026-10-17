import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';

/// Counts every repository round trip so a test can tell a bounded read from an
/// endless one.
class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({List<NotificationModel>? rows, this.signedOut = false})
    : rows = rows ?? const [];

  List<NotificationModel> rows;
  bool signedOut;

  int listCalls = 0;
  int markReadCalls = 0;
  final List<List<String>> markedIds = [];

  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async {
    listCalls++;
    if (signedOut) throw const NotificationSignInRequiredException();
    return rows;
  }

  @override
  Future<int> markRead(List<String> ids) async {
    markReadCalls++;
    markedIds.add(List<String>.of(ids));
    rows = [for (final row in rows) _asRead(row)];
    return ids.length;
  }

  static NotificationModel _asRead(NotificationModel row) => NotificationModel(
    id: row.id,
    titleAr: row.titleAr,
    titleEn: row.titleEn,
    bodyAr: row.bodyAr,
    bodyEn: row.bodyEn,
    type: row.type,
    createdAt: row.createdAt,
    isRead: true,
  );
}

NotificationModel _row(String id, {bool isRead = false}) => NotificationModel(
  id: id,
  titleAr: 'عنوان',
  titleEn: 'Title $id',
  bodyAr: 'نص',
  bodyEn: 'Body $id',
  type: 'order_status',
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  isRead: isRead,
);

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, NotificationsCubit cubit) {
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(
        home: BlocProvider.value(value: cubit, child: const NotificationsPage()),
      ),
    ),
  );
}

/// Frames to push through while the page stays open. Every one of them used to
/// re-enter the builder and schedule another mark-as-read.
const _idleFrames = 40;

void main() {
  group('notifications page does not loop', () {
    testWidgets('staying open issues no further repository calls', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [_row('n1'), _row('n2')],
      );
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await _pumpPage(tester, cubit);

      // Let the visit settle: the constructor load, then the single
      // mark-as-read issued by initState.
      await tester.pump();
      await tester.pump();
      final afterVisit = repository.listCalls;
      expect(afterVisit, 3, reason: 'load, then read + write + read-back');

      for (var i = 0; i < _idleFrames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        repository.listCalls,
        afterVisit,
        reason: 'no state emission may restart the mark-as-read cycle',
      );
      expect(repository.markReadCalls, 1);
      expect(repository.markedIds.single, ['n1', 'n2']);
    });

    testWidgets('a signed-out repository settles instead of retrying', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(signedOut: true);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await _pumpPage(tester, cubit);
      await tester.pump();
      await tester.pump();
      final afterVisit = repository.listCalls;

      for (var i = 0; i < _idleFrames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repository.listCalls, afterVisit);
      expect(cubit.state.signedOut, isTrue);
      expect(cubit.state.notifications, isEmpty);
    });

    testWidgets('the read list still updates after the mark succeeds', (
      tester,
    ) async {
      await _setSurface(tester);
      final repository = _FakeNotificationsRepository(
        rows: [_row('n1'), _row('n2')],
      );
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await _pumpPage(tester, cubit);
      await tester.pump();
      await tester.pump();

      expect(find.byType(NotificationTile), findsNWidgets(2));
      expect(cubit.state.notifications.every((row) => row.isRead), isTrue);
      expect(cubit.unreadCount, 0);
    });
  });

  group('marking current rows is separate from later ones', () {
    test('only the ids unread at call time are written', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('n1')]);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.markAllRead();
      expect(repository.markedIds.single, ['n1']);

      // An id arriving after the visit finished is untouched by it.
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
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.markAllRead();
      expect(repository.markReadCalls, 0);
      expect(repository.markedIds, isEmpty);
    });
  });

  group('notifications cubit initialises exactly once', () {
    test('the constructor is the only initial read', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('n1')]);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(repository.listCalls, 1);

      await cubit.refresh();
      expect(repository.listCalls, 2);
    });

    test('concurrent reads are serialised, never interleaved', () async {
      final repository = _FakeNotificationsRepository(rows: [_row('n1')]);
      final cubit = NotificationsCubit(repository: repository);
      addTearDown(cubit.close);

      await Future.wait([cubit.load(), cubit.markAllRead(), cubit.refresh()]);
      // Three serialised reads plus the single write-and-read-back.
      expect(repository.listCalls, 5);
      expect(repository.markReadCalls, 1);
    });
  });
}