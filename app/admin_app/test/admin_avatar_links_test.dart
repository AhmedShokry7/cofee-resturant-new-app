import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ما طلبه المختبر من التوقيع، لا أكثر: عميل وهمي يسجّل المسارات وأعمارها.
class _Recorder {
  _Recorder({this.urls = const <String, String>{}, this.fail = false});

  final Map<String, String> urls;
  final bool fail;
  final List<List<String>> paths = <List<String>>[];
  final List<int> ttls = <int>[];
  final List<String> buckets = <String>[];
}

/// عميل لا يجيب إلا عن التخزين. الباقي على `noSuchMethod` فأي نداء شبكة ضائع
/// في المختبر يرفض نفسه بنفسه.
class _StubClient implements SupabaseClient {
  _StubClient(this.recorder);

  final _Recorder recorder;

  @override
  SupabaseStorageClient get storage => _StubStorage(recorder);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubStorage implements SupabaseStorageClient {
  _StubStorage(this.recorder);

  final _Recorder recorder;

  @override
  StorageFileApi from(String bucketId) {
    recorder.buckets.add(bucketId);
    return _StubFileApi(recorder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubFileApi implements StorageFileApi {
  _StubFileApi(this.recorder);

  final _Recorder recorder;

  @override
  Future<List<SignedUrlResult>> createSignedUrlsResult(
    List<String> paths,
    int expiresIn, {
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    recorder.paths.add(paths);
    recorder.ttls.add(expiresIn);
    if (recorder.fail) {
      throw Exception('policy denies this object');
    }
    return [
      for (final path in paths)
        if (recorder.urls.containsKey(path))
          SignedUrlSuccess(path: path, signedUrl: recorder.urls[path]!)
        else
          // ملف محذوف وبقي مساره في العمود: التوقيع يفشل لهذا المسار وحده.
          SignedUrlFailure(path: path, error: 'Not Found'),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const path = '534c5b4d-1111-2222-3333-444455556666/avatar_1730000000.jpg';
  const signed = 'https://test.supabase.co/object/sign/avatars/$path?token=x';

  test(
    'a stored path becomes a displayable link, at the top or nested',
    () async {
      final client = _StubClient(_Recorder(urls: {path: signed}));
      final payload = <String, dynamic>{
        'id': 'c1',
        'avatar_url': path,
        'customer': <String, dynamic>{'avatar_url': path},
      };

      final result = await AdminAvatarLinks.signTree(payload, client: client);

      final map = result as Map<String, dynamic>;
      expect(map['avatar_url'], signed);
      expect((map['customer'] as Map)['avatar_url'], signed);
      expect(client.recorder.buckets, <String>[AdminAvatarLinks.bucket]);
      expect(client.recorder.paths.single, <String>[path]);
    },
  );

  test(
    'one batch request carries every distinct path of the payload',
    () async {
      const other = 'bbbbbbbb/avatar_2.jpg';
      final client = _StubClient(
        _Recorder(urls: {path: 'https://t/$path', other: 'https://t/$other'}),
      );
      final payload = <Map<String, dynamic>>[
        <String, dynamic>{'avatar_url': path},
        <String, dynamic>{'avatar_url': path},
        <String, dynamic>{
          'customer': <String, dynamic>{'avatar_url': other},
        },
      ];

      await AdminAvatarLinks.signTree(payload, client: client);

      expect(client.recorder.paths, hasLength(1));
      expect(client.recorder.paths.single.toSet(), {path, other});
      expect(client.recorder.ttls.single, AdminAvatarLinks.ttlSeconds);
    },
  );

  test('a full URL is already displayable and asks for nothing', () async {
    final client = _StubClient(_Recorder());
    final payload = <String, dynamic>{
      'avatar_url': 'https://cdn.example.com/a.jpg',
    };

    final result = await AdminAvatarLinks.signTree(payload, client: client);

    expect((result as Map)['avatar_url'], 'https://cdn.example.com/a.jpg');
    expect(client.recorder.paths, isEmpty);
  });

  test('a payload without any photo makes no storage call at all', () async {
    final client = _StubClient(_Recorder());
    final payload = <Map<String, dynamic>>[
      <String, dynamic>{'id': 'c1', 'avatar_url': null},
      <String, dynamic>{'id': 'c2', 'avatar_url': '   '},
    ];

    final result = await AdminAvatarLinks.signTree(payload, client: client);

    expect(identical(result, payload), isTrue);
    expect(client.recorder.paths, isEmpty);
  });

  test('a denied signing call leaves the rows as they were', () async {
    final client = _StubClient(_Recorder(fail: true));
    final payload = <Map<String, dynamic>>[
      <String, dynamic>{'id': 'c1', 'avatar_url': path},
    ];

    final result = await AdminAvatarLinks.signTree(payload, client: client);

    expect(result, same(payload));
    expect((result as List).first['avatar_url'], path);
  });

  test(
    'a deleted object with a surviving path is not pasted as a link',
    () async {
      final client = _StubClient(
        _Recorder(urls: {path: 'https://t/$path?token=ok'}),
      );
      final payload = <Map<String, dynamic>>[
        <String, dynamic>{'avatar_url': path},
        <String, dynamic>{'avatar_url': 'a1b2/gone.jpg'},
      ];

      final result = await AdminAvatarLinks.signTree(payload, client: client);

      final rows = result as List;
      expect(rows[0]['avatar_url'], 'https://t/$path?token=ok');
      expect(rows[1]['avatar_url'], 'a1b2/gone.jpg');
    },
  );
}
