import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/features/loyalty/data/repositories/admin_loyalty_repository.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_activity_cards.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_activity_table.dart';
import 'package:admin_app/features/subscriptions_admin/data/repositories/admin_subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_avatar.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

/// مختبر يجيب عن `rpc` وعن دلو `avatars` معًا: هذا بالضبط ما تفعله واجهتا
/// القراءة في الإنتاج، وما كان ينقص الاشتراكات وسجل الولاء.
class _Harness {
  _Harness({
    required this.responses,
    this.signed = const <String, String>{},
    this.signThrows = false,
  });

  final Map<String, Object?> responses;

  /// المسارات التي يقبلها التوقيع، لكل منها رابطه. وما ليس هنا يُرفَض.
  final Map<String, String> signed;
  final bool signThrows;

  final List<String> events = <String>[];
  final List<List<String>> signedPaths = <List<String>>[];
  final List<String> buckets = <String>[];

  SupabaseClient get client => _Client(this);
}

class _Client implements SupabaseClient {
  _Client(this.harness);

  final _Harness harness;

  @override
  SupabaseStorageClient get storage => _Storage(harness);

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    harness.events.add('rpc:$fn');
    return _Rpc<T>(payload: harness.responses[fn]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rpc<T> implements PostgrestFilterBuilder<T> {
  _Rpc({required this.payload});

  final Object? payload;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(payload as T).then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SupabaseStorageClient {
  _Storage(this.harness);

  final _Harness harness;

  @override
  StorageFileApi from(String bucketId) {
    harness.buckets.add(bucketId);
    return _Files(harness);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Files implements StorageFileApi {
  _Files(this.harness);

  final _Harness harness;

  @override
  Future<List<SignedUrlResult>> createSignedUrlsResult(
    List<String> paths,
    int expiresIn, {
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    harness.signedPaths.add(paths);
    if (harness.signThrows) throw Exception('policy denies this object');
    return [
      for (final path in paths)
        if (harness.signed.containsKey(path))
          SignedUrlSuccess(path: path, signedUrl: harness.signed[path]!)
        else
          SignedUrlFailure(path: path, error: 'Not Found'),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const String uid = '534c5b4d-1111-2222-3333-444455556666';
const String path = '$uid/avatar_1730000000000000.jpg';
const String link =
    'https://project.supabase.co/storage/v1/object/'
    'sign/avatars/$path?token=x';

Map<String, dynamic> _subscriptionRow({Object? avatar = path}) =>
    <String, dynamic>{
      'id': 's1',
      'user_id': uid,
      'customer_name': 'Sara Ali',
      'customer_email': 'sara@example.com',
      'avatar_url': avatar,
      'plan_name_ar': 'الخطة الذهبية',
      'plan_name_en': 'Gold plan',
      'status': 'active',
      'cups_entitled': 20,
      'cups_used': 5,
    };

Map<String, dynamic> _loyaltyRow({Object? avatar = path}) => <String, dynamic>{
  'id': 't1',
  'user_id': uid,
  'customer_name': 'Sara Ali',
  'customer_email': 'sara@example.com',
  'avatar_url': avatar,
  'points': 20,
  'balance_after': 120,
  'reason': 'earn_order',
  'order_number': 'ORD-101',
};

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AdminSubscription _subscription() =>
    AdminSubscription.fromJson(_subscriptionRow(avatar: link));

AdminLoyaltyTransaction _transaction() =>
    AdminLoyaltyTransaction.fromJson(_loyaltyRow(avatar: link));

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('the subscriptions feed', () {
    test(
      'a stored path becomes a displayable link before the model is built',
      () async {
        final harness = _Harness(
          responses: {
            'admin_subscriptions': <Map<String, dynamic>>[_subscriptionRow()],
          },
          signed: {path: link},
        );

        final rows = await AdminSubscriptionRepository(harness.client)
            .loadSubscriptions();

        expect(rows.single.avatarUrl, link);
        expect(rows.single.customerName, 'Sara Ali');
        expect(harness.buckets, <String>[AdminAvatarLinks.bucket]);
        expect(harness.signedPaths.single, <String>[path]);
      },
    );

    test(
      'the rest of the page survives a signature the bucket refuses',
      () async {
        // عميل بلا صلاحية قراءة، أو ملف حُذف وبقي مساره في العمود: الصف يبقى
        // كاملًا وبلاطة الصورة تطبع حروفها الأولى بدل رابط مكسور.
        final harness = _Harness(
          responses: {
            'admin_subscriptions': <Map<String, dynamic>>[_subscriptionRow()],
          },
          signThrows: true,
        );

        final rows = await AdminSubscriptionRepository(harness.client)
            .loadSubscriptions();

        expect(rows.single.avatarUrl, path);
        expect(rows.single.customerName, 'Sara Ali');
        expect(rows.single.cupsEntitled, 20);
      },
    );

    testWidgets('the avatar tile is handed the link', (tester) async {
      _setViewport(tester, 900);
      final subscription = _subscription();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionAvatar(subscription: subscription, size: 38),
          ),
        ),
      );

      final tile = tester.widget<AdminAvatarImage>(
        find.descendant(
          of: find.byType(SubscriptionAvatar),
          matching: find.byType(AdminAvatarImage),
        ),
      );
      expect(tile.url, link);
    });
  });

  group('the loyalty activity feed', () {
    test(
      'a stored path becomes a displayable link before the model is built',
      () async {
        final harness = _Harness(
          responses: <String, Object?>{
            'admin_loyalty_transactions': <String, Object?>{
              'rows': <Map<String, dynamic>>[_loyaltyRow()],
              'total': 1,
            },
          },
          signed: {path: link},
        );

        final feed = await AdminLoyaltyRepository(harness.client)
            .loadTransactions();

        expect(feed.rows.single.avatarUrl, link);
        expect(feed.rows.single.customerName, 'Sara Ali');
        expect(feed.total, 1);
        expect(harness.buckets, <String>[AdminAvatarLinks.bucket]);
        expect(harness.signedPaths.single, <String>[path]);
      },
    );

    test(
      'the rest of the page survives a signature the bucket refuses',
      () async {
        final harness = _Harness(
          responses: <String, Object?>{
            'admin_loyalty_transactions': <String, Object?>{
              'rows': <Map<String, dynamic>>[_loyaltyRow()],
              'total': 1,
            },
          },
          signThrows: true,
        );

        final feed = await AdminLoyaltyRepository(harness.client)
            .loadTransactions();

        expect(feed.rows.single.avatarUrl, path);
        expect(feed.rows.single.points, 20);
      },
    );

    testWidgets('the table and the cards are handed the link', (tester) async {
      _setViewport(tester, 1200);
      final transactions = <AdminLoyaltyTransaction>[_transaction()];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoyaltyActivityTable(transactions: transactions),
          ),
        ),
      );
      expect(
        tester
            .widget<AdminAvatarImage>(
              find.descendant(
                of: find.byType(LoyaltyActivityTable),
                matching: find.byType(AdminAvatarImage),
              ),
            )
            .url,
        link,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoyaltyActivityCards(transactions: transactions),
          ),
        ),
      );
      expect(
        tester
            .widget<AdminAvatarImage>(
              find.descendant(
                of: find.byType(LoyaltyActivityCards),
                matching: find.byType(AdminAvatarImage),
              ),
            )
            .url,
        link,
      );
    });

    testWidgets('an entry with no picture keeps the initials', (tester) async {
      _setViewport(tester, 1200);
      final withoutPicture = AdminLoyaltyTransaction.fromJson(
        _loyaltyRow(avatar: null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoyaltyActivityTable(
              transactions: <AdminLoyaltyTransaction>[withoutPicture],
            ),
          ),
        ),
      );

      final tile = tester.widget<AdminAvatarImage>(
        find.descendant(
          of: find.byType(LoyaltyActivityTable),
          matching: find.byType(AdminAvatarImage),
        ),
      );
      expect(tile.url, isNull);
      expect(tile.fallbackText, isNotEmpty);
    });
  });
}
