import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_image.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_image_gallery.dart';

/// A one pixel picture, so the preview can be shown.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const AdminProductImage _first = AdminProductImage(
  id: 'img-1',
  productId: 'p1',
  imageUrl: 'https://example.com/one.png',
  sortOrder: 0,
  isPrimary: true,
);

const AdminProductImage _second = AdminProductImage(
  id: 'img-2',
  productId: 'p1',
  imageUrl: 'https://example.com/two.png',
  sortOrder: 1,
);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The gallery shows a spinner while a picture loads, so the frames are
/// pumped one by one instead of waiting for the animations to end.
Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });
  tearDown(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('the picture of the card opens the gallery', (tester) async {
    _setViewport(tester, 900);

    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: ProductCard(
                product: const AdminProduct(
                  id: 'p1',
                  nameAr: 'منتج',
                  nameEn: 'Product',
                  sku: 'SKU-1',
                  slug: 'product',
                  basePrice: 10,
                  imageUrl: 'https://example.com/p.png',
                ),
                categories: const [],
                onOpenImages: () {
                  opened++;
                  showDialog<void>(
                    context: tester.element(find.byType(ProductCard)),
                    builder: (context) => ProductImageGallery(
                      images: const <AdminProductImage>[_first],
                      onAdd: (_, _) async => const <AdminProductImage>[],
                      onReplace: (_, _, _) async => const <AdminProductImage>[],
                      onDelete: (_) async => const <AdminProductImage>[],
                      onSetPrimary: (_) async => const <AdminProductImage>[],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ProductCardImage));
    await _pump(tester);

    expect(opened, 1);
    // The gallery is open and shows the pictures of the product.
    expect(find.text(S.productImages), findsOneWidget);
    expect(find.text(S.addImage), findsOneWidget);
  });

  testWidgets('the gallery shows every picture of the product', (tester) async {
    _setViewport(tester, 900);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first, _second],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    expect(find.text(S.productImages), findsOneWidget);
    // The picture that is the primary one is marked.
    expect(find.text(S.primary), findsOneWidget);
    expect(find.text(S.addImage), findsOneWidget);
    expect(find.text(S.replaceImage), findsOneWidget);
    expect(find.text(S.setPrimaryImage), findsOneWidget);
    expect(find.text(S.delete), findsOneWidget);
  });

  testWidgets('the gallery adds a picture with the given url', (tester) async {
    _setViewport(tester, 900);

    String? addedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[],
            onAdd: (source, _) async {
              addedUrl = source.url;
              return const <AdminProductImage>[_first];
            },
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    expect(find.text(S.noImagesYet), findsOneWidget);

    await tester.tap(find.text(S.addImage));
    await _pump(tester);

    // The admin chooses where the picture comes from.
    await tester.tap(find.text(S.useImageLink));
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, S.imageUrl),
      'https://example.com/new.png',
    );
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await _pump(tester);

    expect(addedUrl, 'https://example.com/new.png');
    // The gallery now shows the picture that was added.
    expect(find.text(S.noImagesYet), findsNothing);
  });

  testWidgets('a failed action keeps the pictures and shows the error', (
    tester,
  ) async {
    _setViewport(tester, 900);

    var reloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first, _second],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReload: () async {
              reloads++;
              return const <AdminProductImage>[_first, _second];
            },
            onReplace: (_, _, _) async =>
                throw const AdminProductException('The picture was not saved.'),
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    await tester.tap(find.text(S.replaceImage));
    await _pump(tester);
    await tester.tap(find.text(S.useImageLink));
    await _pump(tester);
    await tester.enterText(
      find.widgetWithText(TextField, S.imageUrl),
      'https://example.com/new.png',
    );
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await _pump(tester);

    // The error is shown and the gallery keeps its pictures.
    expect(find.text('The picture was not saved.'), findsOneWidget);
    expect(find.text(S.addImage), findsOneWidget);
    expect(reloads, 1);
  });

  testWidgets('a picture is deleted only after the confirmation', (
    tester,
  ) async {
    _setViewport(tester, 900);

    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first, _second],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async {
              deleted++;
              return const <AdminProductImage>[_first];
            },
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, S.delete));
    await _pump(tester);

    // The confirmation is asked first.
    expect(find.text(S.deleteImageConfirm), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.widgetWithText(TextButton, S.cancel));
    await _pump(tester);

    expect(deleted, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, S.delete));
    await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, S.delete));
    await _pump(tester);

    expect(deleted, 1);
  });

  testWidgets('the action runs once while the request is on its way', (
    tester,
  ) async {
    _setViewport(tester, 900);

    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first],
            onAdd: (source, _) async {
              calls++;
              // The request takes a moment, so the admin can press twice.
              await Future<void>.delayed(const Duration(milliseconds: 200));
              return const <AdminProductImage>[_first];
            },
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    await tester.tap(find.text(S.replaceImage));
    await _pump(tester);
    await tester.tap(find.text(S.useImageLink));
    await _pump(tester);
    await tester.enterText(
      find.widgetWithText(TextField, S.imageUrl),
      'https://example.com/new.png',
    );
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await _pump(tester);

    // The buttons are disabled while the request runs, so the action cannot
    // be started twice.
    final replace = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, S.replaceImage),
    );
    expect(replace.onPressed, isNull);
    expect(calls, 0);
  });

  testWidgets('the primary picture is the first one in the column', (
    tester,
  ) async {
    _setViewport(tester, 900);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            // The primary picture is not the first one the rows arrive in.
            images: const <AdminProductImage>[_second, _first],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    // The column shows the primary picture first.
    final column = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(CachedNetworkImage),
    );
    expect(
      tester.widget<CachedNetworkImage>(column.at(0)).imageUrl,
      _first.imageUrl,
    );
    expect(
      tester.widget<CachedNetworkImage>(column.at(1)).imageUrl,
      _second.imageUrl,
    );
  });

  testWidgets('a picture that becomes the primary one moves to the top', (
    tester,
  ) async {
    _setViewport(tester, 900);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first, _second],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (image) async => <AdminProductImage>[
              // The database now marks this picture as the primary one.
              image.copyWith(isPrimary: true),
              _first,
            ],
          ),
        ),
      ),
    );
    await _pump(tester);

    final column = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(CachedNetworkImage),
    );
    expect(
      tester.widget<CachedNetworkImage>(column.at(0)).imageUrl,
      _first.imageUrl,
    );

    // The admin picks the other picture and makes it the primary one.
    final thumbnails = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(InkWell),
    );
    await tester.tap(thumbnails.at(1));
    await tester.pump();
    await tester.tap(find.text(S.setPrimaryImage));
    await _pump(tester);

    // It is the first one of the column right away.
    expect(
      tester.widget<CachedNetworkImage>(column.at(0)).imageUrl,
      _second.imageUrl,
    );
  });

  testWidgets('the small pictures stand in a column beside the big one', (
    tester,
  ) async {
    _setViewport(tester, 900);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first, _second],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    // The pictures of the product are one under the other, in a column.
    final column = tester.widget<ListView>(find.byType(ListView).first);
    expect(column.scrollDirection, Axis.vertical);

    // The big picture takes the room the column leaves.
    expect(find.byType(CachedNetworkImage), findsNWidgets(3));
  });

  testWidgets('the picture that is being written is shown with its state', (
    tester,
  ) async {
    _setViewport(tester, 900);

    final completer = Completer<List<AdminProductImage>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first],
            onPickPicture: () async =>
                ProductImageSource.file(_pngBytes, 'new.png', 'image/png'),
            onAdd: (source, onPhase) {
              onPhase?.call(AdminImageUploadPhase.uploading);
              return completer.future;
            },
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    await tester.tap(find.text(S.addImage));
    await _pump(tester);
    await tester.tap(find.text(S.uploadFromDevice));
    await _pump(tester);

    // The picture the admin picked is shown, with the step it is in.
    expect(find.text(S.uploadingImage), findsOneWidget);
    // The gallery cannot be used again while the picture is written.
    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, S.addImage),
    );
    expect(add.onPressed, isNull);

    // The picture is written.
    completer.complete(const <AdminProductImage>[_first, _second]);
    await _pump(tester);

    // The layer is gone and the new picture is in the gallery.
    expect(find.text(S.uploadingImage), findsNothing);
    expect(find.text(S.primary), findsOneWidget);
  });

  testWidgets('a failed write keeps the pictures that are there', (
    tester,
  ) async {
    _setViewport(tester, 900);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first],
            onPickPicture: () async =>
                ProductImageSource.file(_pngBytes, 'new.png', 'image/png'),
            onAdd: (source, onPhase) async {
              onPhase?.call(AdminImageUploadPhase.uploading);
              throw const AdminProductException('The picture was not saved.');
            },
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (_) async => const <AdminProductImage>[],
          ),
        ),
      ),
    );
    await _pump(tester);

    await tester.tap(find.text(S.addImage));
    await _pump(tester);
    await tester.tap(find.text(S.uploadFromDevice));
    await _pump(tester);

    // The error is shown and the gallery is usable again.
    expect(find.text('The picture was not saved.'), findsOneWidget);
    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, S.addImage),
    );
    expect(add.onPressed, isNotNull);
  });

  testWidgets('the primary picture is chosen for the product', (tester) async {
    _setViewport(tester, 900);

    String? primaryId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: const <AdminProductImage>[_first, _second],
            onAdd: (_, _) async => const <AdminProductImage>[],
            onReplace: (_, _, _) async => const <AdminProductImage>[],
            onDelete: (_) async => const <AdminProductImage>[],
            onSetPrimary: (image) async {
              primaryId = image.id;
              return const <AdminProductImage>[_first, _second];
            },
          ),
        ),
      ),
    );
    await _pump(tester);

    // The second picture is chosen, then it is set as the primary one.
    final thumbnails = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(InkWell),
    );
    await tester.tap(thumbnails.at(1));
    await tester.pump();
    await tester.tap(find.text(S.setPrimaryImage));
    await _pump(tester);

    expect(primaryId, 'img-2');
  });
}
