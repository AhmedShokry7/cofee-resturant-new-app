import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';

/// The removal the dialog is told to run, with a gate the test controls.
class _Removal {
  _Removal({this.fail = false});

  final bool fail;
  final Completer<void> started = Completer<void>();
  final Completer<void> finish = Completer<void>();

  Future<void> call() async {
    started.complete();
    await finish.future;
    if (fail) throw StateError('the row did not change');
  }
}

Future<_Removal> _openDelete(WidgetTester tester, _Removal removal) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => CategoryImageDialog(
                currentImageUrl:
                    'https://project.supabase.co/storage/v1/object/public/'
                    'product-images/products/category-c1/old.jpg',
                onApply: (_) async {},
                onRemove: removal.call,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  final delete = find.text(S.deleteImage);
  await tester.ensureVisible(delete);
  await tester.pumpAndSettle();
  await tester.tap(delete);
  return removal;
}

void main() {
  testWidgets('the dialog stays open while the removal runs', (tester) async {
    final removal = await _openDelete(tester, _Removal());

    await tester.pump();
    expect(removal.started.isCompleted, isTrue);
    expect(find.byType(CategoryImageDialog), findsOneWidget);

    removal.finish.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CategoryImageDialog), findsNothing);
  });

  testWidgets('a failed removal keeps the dialog open with a message', (
    tester,
  ) async {
    final removal = await _openDelete(tester, _Removal(fail: true));

    removal.finish.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CategoryImageDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
