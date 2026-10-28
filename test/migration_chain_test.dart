import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The migration files the Supabase CLI never applies.
///
/// The CLI only applies a file whose name matches `^([0-9]+)_(.*)\.sql$`, and
/// it records the numeric part in `supabase_migrations.schema_migrations`,
/// whose primary key is the version.  A file whose name does not match is
/// skipped silently, and two files with the same version make every
/// `supabase db push` fail on the duplicate key.
///
/// The files below keep their place in the repository because an environment
/// may have applied them by hand.  Their effect has to live in a numbered
/// migration the CLI does apply, otherwise a replay from scratch — `supabase db
/// reset`, a new project — builds a database the app cannot use.  Until 189 that
/// was only true of 002b: 004 never created `permissions.name_en`, 004 still
/// CHECKs a single dot in the permission code, 007 never created
/// `categories.slug`, and 012 still points `variant_key` at `option_values`
/// with a foreign key.  So:
///
///   002b -> 050 (the same body, applied again)
///   004b -> 189 (the English label of a permission)
///   004c -> 189 (the permission code pattern)
///   007b -> 189 (the slug of a category)
///   012b -> 189 (the variant key validation of the stock)
const Map<String, String> knownSkippedFiles = <String, String>{
  '002b_fix_normalize_arabic_digits.sql': '050_fix_normalize_ar_digits.sql',
  '004b_identity_03_permissions_name_en.sql':
      '189_replay_catchup_for_cli_skipped_files.sql',
  '004c_identity_04_permission_code_pattern.sql':
      '189_replay_catchup_for_cli_skipped_files.sql',
  '007b_catalog_05_categories_slug.sql':
      '189_replay_catchup_for_cli_skipped_files.sql',
  '012b_inventory_02_variant_key_validation.sql':
      '189_replay_catchup_for_cli_skipped_files.sql',
};

void main() {
  final directory = Directory('supabase${Platform.pathSeparator}migrations');

  List<File> migrationFiles() =>
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the migration directory exists', () {
    expect(
      directory.existsSync(),
      isTrue,
      reason: 'the migrations live in supabase/migrations',
    );
  });

  test('the files the CLI skips are known and their effect was merged', () {
    final skipped = <String, String>{};
    for (final file in migrationFiles()) {
      final name = file.uri.pathSegments.last;
      if (!RegExp(r'^[0-9]+_.*\.sql$').hasMatch(name)) {
        skipped[name] = file.path;
      }
    }
    expect(
      skipped.keys.toSet(),
      knownSkippedFiles.keys.toSet(),
      reason:
          'a new file that the CLI skips has to be listed here and its '
          'effect has to be merged into a migration the CLI applies',
    );
    for (final entry in knownSkippedFiles.entries) {
      final owner = File(
        '${directory.path}${Platform.pathSeparator}${entry.value}',
      );
      expect(
        owner.existsSync(),
        isTrue,
        reason:
            '${entry.key} is only inert because ${entry.value} carries '
            'its effect',
      );
      expect(
        owner.readAsStringSync(),
        contains(entry.key),
        reason:
            '${entry.value} has to carry the effect of ${entry.key} and '
            'say so',
      );
    }
  });

  test('no two migrations share a version', () {
    final versions = <String, List<String>>{};
    for (final file in migrationFiles()) {
      final name = file.uri.pathSegments.last;
      final match = RegExp(r'^([0-9]+)_').firstMatch(name);
      if (match == null) continue;
      versions.putIfAbsent(match.group(1)!, () => <String>[]).add(name);
    }
    final duplicates = <String, List<String>>{
      for (final entry in versions.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(
      duplicates,
      isEmpty,
      reason:
          'the version is the primary key of the migration ledger: two '
          'files with the same version make every push fail',
    );
  });

  test('the newest migration is above the versions already reviewed', () {
    final versions = migrationFiles()
        .map((file) => file.uri.pathSegments.last)
        .map((name) => RegExp(r'^([0-9]+)_').firstMatch(name))
        .whereType<RegExpMatch>()
        .map((match) => int.parse(match.group(1)!))
        .toList();
    expect(versions, isNotEmpty);
    final newest = versions.reduce((a, b) => a > b ? a : b);
    expect(newest, greaterThanOrEqualTo(104));
  });
}
