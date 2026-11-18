import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/preview/preview_page_routes.dart';

void main() {
  test('every fixed-route editor page is routable in preview', () {
    final source = File(
      'app/admin_app/lib/features/visual_editor/domain/visual_editor_models.dart',
    ).readAsStringSync();
    final start = source.indexOf('class EditorPages {');
    final end = source.indexOf('static EditorPage? findById', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final editorPageIds = RegExp(r"pageId:\s*'([^']+)'")
        .allMatches(source.substring(start, end))
        .map((match) => match.group(1)!)
        .toSet();
    // Product details requires a real ProductModel argument; it is editable
    // but deliberately isn't opened by guessing a fake object in the preview.
    expect(editorPageIds.difference(previewPageRoutes.keys.toSet()), {
      'product_details',
    });
    expect(previewPageRoutes.keys.toSet().difference(editorPageIds), isEmpty);

    expect(
      previewPageRoutes.values.toSet(),
      everyElement(isIn({...AppRoutes.routes.keys, '/splash'})),
    );
  });
}
