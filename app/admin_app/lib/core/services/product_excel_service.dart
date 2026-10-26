import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'package:admin_app/core/locale/app_strings.dart';

/// Reads and writes the small subset of the .xlsx format the product catalogue
/// needs: one sheet, inline or shared strings, no formulas, no styling.
class ProductExcelService {
  ProductExcelService._();

  static const List<String> headers = <String>[
    'Product ID',
    'SKU',
    'Name (Arabic)',
    'Name (English)',
    'Description (Arabic)',
    'Description (English)',
    'Slug',
    'Category',
    'Base Price',
    'Compare-at Price',
    'Discount Percentage',
    'Discount Start Date',
    'Discount End Date',
    'Active',
    'Featured',
    'Prep Minutes',
    'Calories',
    'Allergens',
    'Image URL',
    'Updated At',
  ];

  /// Builds a real .xlsx file from a list of rows. Each row is a list whose
  /// length matches [headers].
  static Uint8List buildWorkbook(List<List<String>> rows) {
    final archive = Archive();

    archive.addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes));
    archive.addFile(ArchiveFile.string('_rels/.rels', _rels));
    archive.addFile(ArchiveFile.string('xl/workbook.xml', _workbook));
    archive.addFile(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels),
    );
    archive.addFile(
      ArchiveFile.string('xl/worksheets/sheet1.xml', _sheet(rows)),
    );

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    return Uint8List.fromList(bytes);
  }

  /// Reads the first worksheet of an .xlsx file into a list of rows. Each row
  /// is padded with empty strings to the width of the widest row.
  static List<List<String>> parseWorkbook(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) {
      throw FormatException(S.noWorksheet);
    }

    final sharedStrings = _readSharedStrings(archive);
    final document = XmlDocument.parse(
      utf8.decode(sheetFile.content as List<int>),
    );

    final rows = <List<String>>[];
    for (final row in document.findAllElements('row')) {
      final cells = row.findElements('c').toList();
      final values = <int, String>{};
      for (final cell in cells) {
        final reference = cell.getAttribute('r') ?? '';
        final column = _columnIndex(reference);
        if (column < 0) continue;
        final type = cell.getAttribute('t');
        String value = '';
        if (type == 's') {
          final index = int.tryParse(
            cell.findElements('v').firstOrNull?.innerText ?? '',
          );
          if (index != null && index >= 0 && index < sharedStrings.length) {
            value = sharedStrings[index];
          }
        } else if (type == 'inlineStr') {
          value = cell.findElements('is').firstOrNull?.innerText ?? '';
        } else {
          value = cell.findElements('v').firstOrNull?.innerText ?? '';
        }
        values[column] = _unescape(value);
      }
      if (values.isEmpty) continue;
      final width = values.keys.reduce((a, b) => a > b ? a : b) + 1;
      final rowValues = List<String>.filled(width, '');
      values.forEach((column, value) => rowValues[column] = value);
      rows.add(rowValues);
    }
    return rows;
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const <String>[];
    final document = XmlDocument.parse(utf8.decode(file.content as List<int>));
    final strings = <String>[];
    for (final item in document.findAllElements('si')) {
      strings.add(item.innerText);
    }
    return strings;
  }

  static String _sheet(List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      buffer.write('<row r="${rowIndex + 1}">');
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final reference = '${_columnLetter(columnIndex)}${rowIndex + 1}';
        buffer.write(
          '<c r="$reference" t="inlineStr"><is><t>${_escape(row[columnIndex])}</t></is></c>',
        );
      }
      buffer.write('</row>');
    }
    buffer.write('</sheetData></worksheet>');
    return buffer.toString();
  }

  static int _columnIndex(String reference) {
    final match = RegExp(r'^([A-Z]+)').firstMatch(reference);
    if (match == null) return -1;
    final letters = match.group(1)!;
    var index = 0;
    for (final code in letters.codeUnits) {
      index = index * 26 + (code - 64);
    }
    return index - 1;
  }

  static String _columnLetter(int index) {
    var value = index + 1;
    final buffer = StringBuffer();
    while (value > 0) {
      final remainder = (value - 1) % 26;
      buffer.writeCharCode(65 + remainder);
      value = (value - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unescape(String value) {
    return value
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';

  static const String _rels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _workbook =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Products" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const String _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>';
}
