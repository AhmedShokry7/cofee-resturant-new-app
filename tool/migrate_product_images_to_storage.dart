// One-off maintenance script: migrates product pictures hosted on the
// merchant's menu site into our own Supabase Storage bucket.
//
// WHY: the menu host does not send CORS headers, so the web build (the visual
// editor's preview) cannot fetch its bytes and shows a broken-picture icon.
// Our own storage sends `Access-Control-Allow-Origin: *`, so every picture it
// hosts takes the same fast, cached path everywhere.
//
// WHAT IT DOES
//   1. Signs in as a staff account (the catalogue tables are written through
//      row level security, the way the dashboard writes them).
//   2. Reads every product and product-image row whose URL is off-site.
//   3. Downloads the picture, uploads it to the `product-images` bucket under
//      the row's own folder, and rewrites the row. The product's display url
//      follows through the `catalog.sync_product_image_url` trigger.
//   4. Prints a report; re-running is safe (it skips rows already migrated).
//
// USAGE (from the project root, with credentials in env):
//   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... \
//   SUPABASE_ADMIN_EMAIL=... SUPABASE_ADMIN_PASSWORD=... \
//   dart run tool/migrate_product_images_to_storage.dart
//
// سكربت صيانة يُشغَّل مرة: ينقل صور المنتجات المركّزة على موقع القائمة
// الخارجي إلى تخزين Supabase الخاص بنا، ويحدّث الروابط في الجدول.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main(List<String> args) {
  _run(
    supabaseUrl: Platform.environment['SUPABASE_URL'] ?? '',
    publishableKey: Platform.environment['SUPABASE_PUBLISHABLE_KEY'] ?? '',
    adminEmail: Platform.environment['SUPABASE_ADMIN_EMAIL'] ?? '',
    adminPassword: Platform.environment['SUPABASE_ADMIN_PASSWORD'] ?? '',
    dryRun: args.contains('--dry-run'),
  );
}

const _bucket = 'product-images';
const _storageBaseSuffix = '/storage/v1/object/public/$_bucket/';

Future<void> _run({
  required String supabaseUrl,
  required String publishableKey,
  required String adminEmail,
  required String adminPassword,
  required bool dryRun,
}) async {
  if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
    stderr.writeln('SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY مطلوبان في البيئة.');
    exit(2);
  }
  if (adminEmail.isEmpty || adminPassword.isEmpty) {
    stderr.writeln(
      'SUPABASE_ADMIN_EMAIL و SUPABASE_ADMIN_PASSWORD مطلوبان — جدول الكتالوج '
      'يُكتب بصلاحيات مستخدم موظف (سياسات RLS)، لا بمفتاح الخدمة.',
    );
    exit(2);
  }
  final client = http.Client();
  try {
    final staffToken = await _signIn(
      client,
      supabaseUrl,
      publishableKey,
      adminEmail,
      adminPassword,
    );

    var migrated = 0;
    var skipped = 0;
    var failed = 0;

    // 1) المنتجات: كل صف صورته خارج استضافتنا.
    //    لا يمكن تحديث products مباشرة (إنه عرض يضمّ التصنيف)، لكن الجدول
    //    الأساسي يُزامَن من تريغر `catalog.sync_product_image_url` كلما
    //    تغيّرت الصورة الأساسية في product_images — فالكتابة تمر من هناك.
    final products = await _listRows(
      client,
      supabaseUrl,
      publishableKey,
      staffToken,
      'products',
      'id,image_url',
    );
    for (final row in products) {
      final url = (row['image_url'] as String?)?.trim() ?? '';
      if (url.isEmpty || _isOurs(url, supabaseUrl)) {
        skipped++;
        continue;
      }
      final ok = await _migrateProductImage(
        client,
        supabaseUrl,
        publishableKey,
        staffToken,
        productId: row['id'] as String,
        source: url,
        dryRun: dryRun,
      );
      ok ? migrated++ : failed++;
    }

    // 2) صور المنتجات الإضافية (جدول product_images) — هذا جدول حقيقي
    //    قابل للتحديث المباشر.
    final extra = await _listRows(
      client,
      supabaseUrl,
      publishableKey,
      staffToken,
      'product_images',
      'id,product_id,image_url',
    );
    for (final row in extra) {
      final url = (row['image_url'] as String?)?.trim() ?? '';
      if (url.isEmpty || _isOurs(url, supabaseUrl)) {
        skipped++;
        continue;
      }
      final destination = 'products/${row['product_id'] as String}/'
          '${Uri.parse(url).pathSegments.last}';
      final ok = await _uploadAndPatchRow(
        client,
        supabaseUrl,
        publishableKey,
        staffToken,
        source: url,
        destination: destination,
        patchTable: 'product_images',
        patchFilter: 'id=eq.${row['id'] as String}',
        dryRun: dryRun,
      );
      ok ? migrated++ : failed++;
    }

    stdout.writeln(
      'انتهى: مهاجرة $migrated، متخطاة (مكوّنة عندنا) $skipped، فاشلة $failed'
      '${dryRun ? ' (تشغيل تجريبي — لم يتغير شيء)' : ''}',
    );
    if (failed > 0) exit(1);
  } finally {
    client.close();
  }
}

bool _isOurs(String url, String supabaseUrl) =>
    url.startsWith('$supabaseUrl/storage');

/// Signs in a staff account and returns its access token.
Future<String> _signIn(
  http.Client client,
  String supabaseUrl,
  String publishableKey,
  String email,
  String password,
) async {
  final res = await client.post(
    Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': publishableKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (res.statusCode != 200) {
    stderr.writeln('تسجيل الدخول فشل: ${res.statusCode}');
    exit(2);
  }
  final token = (jsonDecode(res.body) as Map<String, dynamic>)['access_token']
      as String?;
  if (token == null || token.isEmpty) {
    stderr.writeln('لم يصل رمز الوصول في رد تسجيل الدخول.');
    exit(2);
  }
  return token;
}

Map<String, String> _restHeaders(String publishableKey, String staffToken) => {
  'apikey': publishableKey,
  'Authorization': 'Bearer $staffToken',
  'Content-Type': 'application/json',
};

Future<List<dynamic>> _listRows(
  http.Client client,
  String supabaseUrl,
  String publishableKey,
  String staffToken,
  String table,
  String columns,
) async {
  final res = await client.get(
    Uri.parse('$supabaseUrl/rest/v1/$table?select=$columns&limit=1000'),
    headers: _restHeaders(publishableKey, staffToken),
  );
  if (res.statusCode != 200) {
    stderr.writeln('قراءة $table فشلت: ${res.statusCode} ${res.body}');
    exit(2);
  }
  return jsonDecode(res.body) as List<dynamic>;
}

/// Migrates one product's display picture.
///
/// `products` is a joined view — PostgREST refuses to update it. The display
/// url is kept in step by the `catalog.sync_product_image_url` trigger,
/// which reads the primary row of `product_images` every time it changes.
/// So the write goes through that table:
///
/// - a gallery row already pointing at the source url is updated in place;
/// - a product without gallery rows gets its first, primary row (the same
///   import the dashboard does when it opens an old product);
/// - a product whose gallery holds other pictures gets a new non-primary
///   row, and the display url is left for the staff to settle by hand.
Future<bool> _migrateProductImage(
  http.Client client,
  String supabaseUrl,
  String publishableKey,
  String staffToken, {
  required String productId,
  required String source,
  required bool dryRun,
}) async {
  final fileName = Uri.parse(source).pathSegments.last;
  final destination = 'products/product-$productId/$fileName';
  final publicUrl = '$supabaseUrl$_storageBaseSuffix$destination';

  final gallery = await _listRows(
    client,
    supabaseUrl,
    publishableKey,
    staffToken,
    'product_images',
    'id,product_id,image_url',
  );
  final mine = gallery
      .whereType<Map>()
      .where((r) => r['product_id'] == productId)
      .toList();
  final matching = mine.where((r) => r['image_url'] == source).toList();

  if (dryRun) {
    stdout.writeln(
      '  (تجريبي) صورة $productId → $destination '
      '(${matching.isNotEmpty ? 'تحديث صف المعرض' : mine.isEmpty ? 'صف أساسي جديد' : 'صف غير أساسي'})',
    );
    return true;
  }

  final uploaded = await _upload(
    client,
    supabaseUrl,
    publishableKey,
    staffToken,
    source: source,
    destination: destination,
  );
  if (!uploaded) return false;

  if (matching.isNotEmpty) {
    final id = matching.first['id'] as String;
    final ok = await _patch(
      client,
      supabaseUrl,
      publishableKey,
      staffToken,
      table: 'product_images',
      filter: 'id=eq.$id',
      changes: {'image_url': publicUrl},
    );
    if (!ok) return false;
  } else {
    // صف المعرض الأول أو الإضافي. التريغر يقرأ الصورة الأساسية ويزامن
    // عمود ظهور المنتج.
    final inserted = await client.post(
      Uri.parse('$supabaseUrl/rest/v1/product_images'),
      headers: _restHeaders(publishableKey, staffToken)
        ..['Prefer'] = 'return=minimal',
      body: jsonEncode({
        'product_id': productId,
        'image_url': publicUrl,
        'sort_order': mine.length,
        'is_primary': mine.isEmpty,
      }),
    );
    if (inserted.statusCode != 201 && inserted.statusCode != 200) {
      stderr.writeln(
        '  فشل إدراج صف المعرض: ${inserted.statusCode} ${inserted.body}',
      );
      return false;
    }
    if (mine.isNotEmpty) {
      stdout.writeln('  ⚠ صورة أساسية أخرى موجودة — لم يُغيَّر ظهور المنتج تلقائيًا.');
    }
  }

  stdout.writeln('  ✓ $publicUrl');
  return true;
}

Future<bool> _uploadAndPatchRow(
  http.Client client,
  String supabaseUrl,
  String publishableKey,
  String staffToken, {
  required String source,
  required String destination,
  required String patchTable,
  required String patchFilter,
  required bool dryRun,
}) async {
  final publicUrl = '$supabaseUrl$_storageBaseSuffix$destination';
  if (dryRun) {
    stdout.writeln('  (تجريبي) صورة $source → $destination');
    return true;
  }
  final uploaded = await _upload(
    client,
    supabaseUrl,
    publishableKey,
    staffToken,
    source: source,
    destination: destination,
  );
  if (!uploaded) return false;
  final ok = await _patch(
    client,
    supabaseUrl,
    publishableKey,
    staffToken,
    table: patchTable,
    filter: patchFilter,
    changes: {'image_url': publicUrl},
  );
  if (!ok) return false;
  stdout.writeln('  ✓ $publicUrl');
  return true;
}

Future<bool> _upload(
  http.Client client,
  String supabaseUrl,
  String publishableKey,
  String staffToken, {
  required String source,
  required String destination,
}) async {
  stdout.writeln('− تنزيل $source');
  final imageRes = await client.get(Uri.parse(source));
  if (imageRes.statusCode != 200) {
    stderr.writeln('  فشل التنزيل: ${imageRes.statusCode} — أُترك الرابط كما هو.');
    return false;
  }
  final contentType = imageRes.headers['content-type'] ?? 'image/jpeg';
  if (!contentType.startsWith('image/')) {
    stderr.writeln('  ليس صورة ($contentType) — أُترك الرابط كما هو.');
    return false;
  }

  // الرفع إلى التخزين بصلاحيات الموظف (نفس ما ترفع به لوحة التحكم).
  // x-upsert يسمح بإعادة التشغيل على نفس المسار.
  final upload = await client.post(
    Uri.parse('$supabaseUrl/storage/v1/object/$_bucket/$destination'),
    headers: {
      'apikey': publishableKey,
      'Authorization': 'Bearer $staffToken',
      'Content-Type': contentType,
      'x-upsert': 'true',
      'Cache-Control': '31536000',
    },
    body: imageRes.bodyBytes,
  );
  if (upload.statusCode != 200 && upload.statusCode != 201) {
    stderr.writeln('  فشل الرفع: ${upload.statusCode} ${upload.body}');
    return false;
  }
  return true;
}

Future<bool> _patch(
  http.Client client,
  String supabaseUrl,
  String publishableKey,
  String staffToken, {
  required String table,
  required String filter,
  required Map<String, dynamic> changes,
}) async {
  final patch = await client.patch(
    Uri.parse('$supabaseUrl/rest/v1/$table?$filter'),
    headers: _restHeaders(publishableKey, staffToken)
      ..['Prefer'] = 'return=minimal',
    body: jsonEncode(changes),
  );
  if (patch.statusCode != 200 && patch.statusCode != 204) {
    stderr.writeln('  فشل تحديث $table: ${patch.statusCode} ${patch.body}');
    return false;
  }
  return true;
}
