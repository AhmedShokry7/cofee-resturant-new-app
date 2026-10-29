import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/staff/data/repositories/admin_staff_repository.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';

/// Client that answers `rpc` and the `avatars` bucket and records both in the
/// order they happened.
///
/// The order is the point: a picture file must never be deleted before the row
/// stops naming it, and a file the row refused must not stay in the bucket.
class _Harness {
  _Harness({
    this.responses = const <String, Object?>{},
    this.errors = const <String, Object>{},
    this.signed = const <String, String>{},
  });

  /// What each `rpc` answers, by function name.
  final Map<String, Object?> responses;

  /// What each `rpc` throws instead, by function name.
  final Map<String, Object> errors;

  /// The signed url handed out for a stored path.
  final Map<String, String> signed;

  /// Every call, in the order the repository made it.
  final List<String> events = <String>[];

  /// The params of the last call to each function.
  final Map<String, Map<String, dynamic>> params =
      <String, Map<String, dynamic>>{};

  AdminStaffRepository get repository => AdminStaffRepository(_Client(this));

  static const String bucket = 'avatars';

  /// The object path of the first file the bucket took.
  String get firstUpload {
    final event = events.firstWhere((event) => event.startsWith('upload:'));
    return event.substring('upload:$bucket/'.length);
  }

  List<String> get removals =>
      events.where((event) => event.startsWith('remove:')).toList();
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
    if (params != null) harness.params[fn] = params;
    return _Rpc<T>(payload: harness.responses[fn], error: harness.errors[fn]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rpc<T> implements PostgrestFilterBuilder<T> {
  _Rpc({required this.payload, required this.error});

  final Object? payload;
  final Object? error;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    final thrown = error;
    final source = thrown != null
        ? Future<T>.error(thrown, StackTrace.current)
        : Future<T>.value(payload as T);
    return source.then(onValue, onError: onError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SupabaseStorageClient {
  _Storage(this.harness);

  final _Harness harness;

  @override
  StorageFileApi from(String bucketId) => _Files(harness, bucketId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Files implements StorageFileApi {
  _Files(this.harness, this.bucketId);

  final _Harness harness;

  /// الاسم الذي تعطيه واجهة التخزين نفسها للدلو.
  @override
  final String bucketId;

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    harness.events.add('upload:$bucketId/$path');
    return 'https://project.supabase.co/storage/v1/object/sign/'
        '$bucketId/$path';
  }

  @override
  Future<List<FileObject>> remove(List<String> paths) async {
    for (final path in paths) {
      harness.events.add('remove:$bucketId/$path');
    }
    return const <FileObject>[];
  }

  @override
  Future<List<SignedUrlResult>> createSignedUrlsResult(
    List<String> paths,
    int expiresIn, {
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    harness.events.add('sign:${paths.join(',')}');
    return [
      for (final path in paths)
        SignedUrlSuccess(
          path: path,
          signedUrl: harness.signed[path] ?? 'https://signed/$path',
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PostgrestException _denied() =>
    PostgrestException(message: 'permission denied', code: '42501');

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  const staffPath = 'staff/staff-1/1730000000000000.jpg';
  final bytes = Uint8List.fromList(List<int>.filled(64, 7));

  test(
    'the stored path becomes a signed link before the model is built',
    () async {
      final harness = _Harness(
        responses: {
          'admin_staff': <Map<String, dynamic>>[
            {
              'id': 'staff-1',
              'user_id': 'user-1',
              'full_name': 'Cashier One',
              'status': 'active',
              'avatar_url': staffPath,
            },
          ],
        },
        signed: {staffPath: 'https://signed/for-one-hour'},
      );

      final staff = await harness.repository.loadStaff();

      expect(staff.single.avatarUrl, 'https://signed/for-one-hour');
      expect(harness.events, contains('sign:$staffPath'));
    },
  );

  test('an account without a picture asks the bucket for nothing', () async {
    final harness = _Harness(
      responses: {
        'admin_staff': <Map<String, dynamic>>[
          {'id': 'staff-2', 'user_id': 'user-2', 'status': 'invited'},
        ],
      },
    );

    final staff = await harness.repository.loadStaff();

    expect(staff.single.avatarUrl, isNull);
    expect(harness.events, ['rpc:admin_staff']);
  });

  test(
    'every refusal reason of the edit function has its own outcome',
    () async {
      final cases = <String, StaffEditOutcome>{
        'self_status': StaffEditOutcome.selfStatus,
        'invalid_name': StaffEditOutcome.invalidName,
        'invalid_email': StaffEditOutcome.invalidEmail,
        'duplicate_email': StaffEditOutcome.duplicateEmail,
        'invalid_status': StaffEditOutcome.invalidStatus,
        'invalid_path': StaffEditOutcome.invalidPath,
        'untranslated': StaffEditOutcome.failed,
      };
      for (final entry in cases.entries) {
        final harness = _Harness(
          responses: {
            'admin_update_staff': {'ok': false, 'reason': entry.key},
          },
        );
        expect(
          await harness.repository.updateStaff(
            staffId: 'staff-1',
            fullName: 'N',
          ),
          entry.value,
          reason: entry.key,
        );
      }
    },
  );

  test('an ok answer is a success, and an unwritten field travels as null', () async {
    final harness = _Harness(
      responses: {
        'admin_update_staff': {'ok': true},
      },
    );

    final outcome = await harness.repository.updateStaff(
      staffId: 'staff-1',
      fullName: 'Only The Name',
    );

    expect(outcome, StaffEditOutcome.success);
    // The function reads a null as «leave that column alone», so a dialog that
    // only renamed the account cannot rewrite the email from a stale value.
    expect(harness.params['admin_update_staff'], <String, dynamic>{
      'p_staff_id': 'staff-1',
      'p_full_name': 'Only The Name',
      'p_email': null,
      'p_status': null,
    });
  });

  test(
    'the privilege wall is a denial and any other fault is a failure',
    () async {
      expect(
        await _Harness(errors: {'admin_update_staff': _denied()}).repository
            .updateStaff(staffId: 's'),
        StaffEditOutcome.permissionDenied,
      );
      expect(
        await _Harness(
          errors: {
            'admin_update_staff': PostgrestException(
              message: 'deadlock',
              code: '40P01',
            ),
          },
        ).repository.updateStaff(staffId: 's'),
        StaffEditOutcome.failed,
      );
      expect(
        await _Harness(errors: {'admin_update_staff': Exception('offline')})
            .repository
            .updateStaff(staffId: 's'),
        StaffEditOutcome.failed,
      );
    },
  );

  test('the picture of an account is written into its own folder', () async {
    final harness = _Harness(
      responses: {
        'admin_set_staff_image': {'ok': true},
      },
    );

    final outcome = await harness.repository.uploadStaffImage(
      staffId: 'staff-1',
      bytes: bytes,
      fileName: 'cup.png',
      contentType: 'image/png',
    );

    expect(outcome, StaffEditOutcome.success);
    // The folder is the staff id and the column constraint of migration 209
    // only accepts that shape, so a path built here wrong is refused there.
    expect(harness.firstUpload, matches(RegExp(r'^staff/staff-1/\d+\.png$')));
    expect(
      harness.params['admin_set_staff_image']!['p_avatar_url'],
      harness.firstUpload,
    );
    expect(
      harness.events.indexOf('rpc:admin_set_staff_image'),
      greaterThan(
        harness.events.indexOf(
          'upload:${_Harness.bucket}/${harness.firstUpload}',
        ),
      ),
    );
  });

  test('a refused row drops the fresh file and keeps the old one', () async {
    final harness = _Harness(
      responses: {
        'admin_set_staff_image': {'ok': false, 'reason': 'invalid_path'},
      },
    );

    final outcome = await harness.repository.uploadStaffImage(
      staffId: 'staff-1',
      bytes: bytes,
      fileName: 'cup.jpg',
      contentType: 'image/jpeg',
      replaces:
          'https://project/object/sign/avatars/staff/staff-1/old.jpg?token=x',
    );

    expect(outcome, StaffEditOutcome.invalidPath);
    expect(harness.removals, ['remove:avatars/${harness.firstUpload}']);
  });

  test(
    'the previous file is deleted only after the row names the new one',
    () async {
      final harness = _Harness(
        responses: {
          'admin_set_staff_image': {'ok': true},
        },
      );

      await harness.repository.uploadStaffImage(
        staffId: 'staff-1',
        bytes: bytes,
        fileName: 'a.jpeg',
        contentType: 'image/jpeg',
        replaces:
            'https://project/object/sign/avatars/staff/staff-1/999.jpg?token=x',
      );

      // `.jpeg` is stored as `.jpg`, the extension the pick service hands back.
      expect(harness.firstUpload, matches(RegExp(r'^staff/staff-1/\d+\.jpg$')));
      expect(harness.removals, ['remove:avatars/staff/staff-1/999.jpg']);
      expect(
        harness.events.indexOf('remove:avatars/staff/staff-1/999.jpg'),
        greaterThan(harness.events.indexOf('rpc:admin_set_staff_image')),
      );
    },
  );

  test('an empty or oversized file never reaches the bucket', () async {
    final harness = _Harness();

    await expectLater(
      harness.repository.uploadStaffImage(
        staffId: 'staff-1',
        bytes: Uint8List(0),
        fileName: 'a.jpg',
        contentType: 'image/jpeg',
      ),
      throwsA(isA<AdminProductException>()),
    );
    await expectLater(
      harness.repository.uploadStaffImage(
        staffId: 'staff-1',
        bytes: Uint8List(adminImageMaxBytes + 1),
        fileName: 'a.jpg',
        contentType: 'image/jpeg',
      ),
      throwsA(isA<AdminProductException>()),
    );
    expect(harness.events, isEmpty);
  });

  test('the deleted object is found from the link the screen holds', () async {
    final harness = _Harness();
    await harness.repository.deleteStaffImageFile(
      'https://project/object/sign/avatars/staff/staff-1/999.jpg?token=x',
    );
    expect(harness.removals, ['remove:avatars/staff/staff-1/999.jpg']);

    // A picture hosted anywhere else is not this bucket's business: the
    // screen must not delete bytes it does not own.
    final elsewhere = _Harness();
    await elsewhere.repository.deleteStaffImageFile(
      'https://menu.example.com/elsewhere.jpg',
    );
    expect(elsewhere.events, isEmpty);
  });

  test('clearing the picture writes a null path', () async {
    final harness = _Harness(
      responses: {
        'admin_set_staff_image': {'ok': true},
      },
    );

    expect(
      await harness.repository.setStaffImage('staff-1', null),
      StaffEditOutcome.success,
    );
    expect(harness.params['admin_set_staff_image'], <String, dynamic>{
      'p_staff_id': 'staff-1',
      'p_avatar_url': null,
    });
  });
}
