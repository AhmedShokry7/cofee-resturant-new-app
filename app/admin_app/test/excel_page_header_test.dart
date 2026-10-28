import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_page_header.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_header.dart';
import 'package:admin_app/shared/widgets/admin_excel_button.dart';
import 'package:admin_app/shared/widgets/admin_excel_page_header.dart';
import 'package:admin_app/shared/widgets/admin_export_button.dart';
import 'package:admin_app/shared/widgets/admin_import_excel_dialog.dart';
import 'package:admin_app/shared/widgets/excel_icon.dart';

/// The Excel mark at one size, so every place proves its own scale.
Finder _mark(double size) => find.byWidgetPredicate(
  (widget) => widget is ExcelIcon && widget.size == size,
);

Future<void> _pump(WidgetTester tester, Widget header) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: header)));
  await tester.pump();
}

/// The products header of the page, with every Excel action wired to [calls].
ProductPageHeader _products(
  List<String> calls, {
  double? importProgress,
  double? exportProgress,
  int selectedCount = 0,
  bool withExcel = true,
}) => ProductPageHeader(
  count: 2,
  selectedCount: selectedCount,
  onAdd: () => calls.add('add'),
  onSelectAll: () => calls.add('select'),
  onClearSelection: () => calls.add('clear'),
  onDeleteSelected: () => calls.add('delete'),
  onPickFile: withExcel ? () => calls.add('pick') : null,
  onDownloadSample: withExcel ? () => calls.add('template') : null,
  onExport: withExcel ? () => calls.add('export') : null,
  importProgress: importProgress,
  exportProgress: exportProgress,
);

CategoryPageHeader _categories(
  List<String> calls, {
  double? importProgress,
  double? exportProgress,
  int selectedCount = 0,
}) => CategoryPageHeader(
  count: 2,
  selectedCount: selectedCount,
  onAdd: () => calls.add('add'),
  onSelectAll: () => calls.add('select'),
  onClearSelection: () => calls.add('clear'),
  onDeleteSelected: () => calls.add('delete'),
  onPickFile: () => calls.add('pick'),
  onDownloadSample: () => calls.add('template'),
  onExport: () => calls.add('export'),
  importProgress: importProgress,
  exportProgress: exportProgress,
);

Future<void> _openChoice(WidgetTester tester) async {
  await tester.tap(find.text(S.excelImport));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('the shared Excel header', () {
    testWidgets('is the one widget behind the products and categories pages', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _products(calls));
      expect(find.byType(AdminExcelPageHeader), findsOneWidget);

      await _pump(tester, _categories(calls));
      expect(find.byType(AdminExcelPageHeader), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType == AdminExcelPageHeader,
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers both pages the same template-or-file choice', (
      tester,
    ) async {
      for (final header in <Widget>[
        _products(<String>[]),
        _categories(<String>[]),
      ]) {
        await _pump(tester, header);
        await _openChoice(tester);

        expect(find.byType(AdminImportExcelDialog), findsOneWidget);
        expect(find.text(S.downloadSampleFile), findsOneWidget);
        expect(find.text(S.uploadFromDevice), findsOneWidget);

        await tester.tap(find.text(S.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(AdminImportExcelDialog), findsNothing);
      }
    });

    testWidgets('a chosen file runs the page import and closes the dialog', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _categories(calls));
      await _openChoice(tester);

      await tester.tap(find.text(S.uploadFromDevice));
      await tester.pumpAndSettle();

      expect(calls, <String>['pick']);
      expect(find.byType(AdminImportExcelDialog), findsNothing);
    });

    testWidgets('a chosen template runs the page template download', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _products(calls));
      await _openChoice(tester);

      await tester.tap(find.text(S.downloadSampleFile));
      await tester.pumpAndSettle();

      expect(calls, <String>['template']);
      expect(find.byType(AdminImportExcelDialog), findsNothing);
    });

    testWidgets('the export label runs the page export directly', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _products(calls));

      await tester.tap(find.text(S.excelExport));
      await tester.pumpAndSettle();

      expect(calls, <String>['export']);
      expect(find.byType(AdminImportExcelDialog), findsNothing);
    });

    testWidgets('a running import locks every action and labels the bar', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _products(calls, importProgress: 0.4));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(S.importing), findsOneWidget);

      await tester.tap(find.text(S.excelImport), warnIfMissed: false);
      await tester.tap(find.text(S.excelExport), warnIfMissed: false);
      await tester.tap(find.text(S.addProduct), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.byType(AdminImportExcelDialog), findsNothing);
    });

    testWidgets('a running export locks the actions the same way', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _categories(calls, exportProgress: 0.8));

      expect(find.text(S.exporting), findsOneWidget);

      await tester.tap(find.text(S.excelImport), warnIfMissed: false);
      await tester.tap(find.text(S.excelExport), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('hides both Excel actions when the page has none', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _products(calls, withExcel: false));

      expect(find.text(S.excelImport), findsNothing);
      expect(find.text(S.excelExport), findsNothing);
      expect(find.byType(ExcelIcon), findsNothing);

      await tester.tap(find.text(S.addProduct));
      await tester.pumpAndSettle();
      expect(calls, <String>['add']);
    });

    testWidgets('keeps the heading and the add label of each page', (
      tester,
    ) async {
      await _pump(tester, _products(<String>[]));
      expect(find.text(S.products), findsOneWidget);
      expect(find.text(S.productsCount(2)), findsOneWidget);
      expect(find.text(S.addProduct), findsOneWidget);

      await _pump(tester, _categories(<String>[]));
      expect(find.text(S.categories), findsOneWidget);
      expect(find.text(S.categoriesCount(2)), findsOneWidget);
      expect(find.text(S.addCategory), findsOneWidget);
    });

    testWidgets('shows the bulk row of the page only once it picks records', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, _products(calls));
      expect(find.text(S.selectAllProducts(2)), findsNothing);

      await _pump(tester, _products(calls, selectedCount: 1));
      await tester.tap(find.text(S.selectAllProducts(2)));
      await tester.pumpAndSettle();
      expect(find.text(S.selectedProductsCount(1)), findsOneWidget);
      expect(calls, <String>['select']);

      await _pump(tester, _categories(calls, selectedCount: 2));
      expect(find.text(S.selectedCountLabel(2)), findsOneWidget);
      expect(find.text(S.deleteSelectedCategories), findsOneWidget);
    });
  });

  group('the Excel mark', () {
    testWidgets('stands beside the import and export words on both pages', (
      tester,
    ) async {
      for (final header in <Widget>[
        _products(<String>[]),
        _categories(<String>[]),
      ]) {
        await _pump(tester, header);

        expect(find.text(S.excelImport), findsOneWidget);
        expect(find.text(S.excelExport), findsOneWidget);
        expect(find.byType(AdminExcelButton), findsNWidgets(2));
        expect(_mark(16), findsNWidgets(2));
      }
    });

    testWidgets('shrinks to the size of the choice dialog buttons', (
      tester,
    ) async {
      await _pump(tester, _products(<String>[]));
      await _openChoice(tester);

      expect(
        find.descendant(
          of: find.byType(AdminImportExcelDialog),
          matching: find.byType(ExcelIcon),
        ),
        findsNWidgets(2),
      );
      expect(_mark(18), findsNWidgets(2));
      expect(find.byType(ExcelIcon), findsNWidgets(4));
    });

    testWidgets('marks the export button of a directory toolbar', (
      tester,
    ) async {
      await _pump(
        tester,
        AdminExportButton(
          label: S.ordersExportExcel,
          busyLabel: S.ordersExporting,
          onPressed: () {},
        ),
      );

      expect(find.byType(ExcelIcon), findsOneWidget);
      expect(_mark(16), findsOneWidget);
      expect(find.text(S.ordersExportExcel), findsOneWidget);
    });
  });
}
