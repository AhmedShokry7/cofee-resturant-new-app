import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/product_excel_service.dart';

/// A single row that failed to import, with the reason.
class ImportRowError {
  const ImportRowError({
    required this.rowNumber,
    required this.reason,
    this.productName,
  });

  final int rowNumber;
  final String reason;
  final String? productName;
}

/// The products read from a workbook, and the rows that were left out.
class ProductExcelImport {
  const ProductExcelImport({
    required this.products,
    required this.invalidRows,
    required this.rowCount,
    this.errors = const <ImportRowError>[],
  });

  final List<AdminProduct> products;
  final int invalidRows;
  final int rowCount;
  final List<ImportRowError> errors;
}

/// Turns the products of the catalogue into workbook rows and back.
class ProductExcelMapper {
  ProductExcelMapper._();

  /// The workbook of the products, with the header row on top.
  static List<List<String>> toRows(Iterable<AdminProduct> products) {
    final rows = <List<String>>[ProductExcelService.headers];
    for (final product in products) {
      rows.add(<String>[
        product.id,
        product.sku,
        product.nameAr,
        product.nameEn,
        product.descriptionAr ?? '',
        product.descriptionEn ?? '',
        product.slug,
        _categoryName(product),
        product.basePrice.toString(),
        product.compareAtPrice?.toString() ?? '',
        product.discountPercentage?.toString() ?? '',
        _date(product.discountStartsAt),
        _date(product.discountEndsAt),
        product.isActive ? 'TRUE' : 'FALSE',
        product.isFeatured ? 'TRUE' : 'FALSE',
        product.prepMinutes?.toString() ?? '',
        product.calories?.toString() ?? '',
        product.allergens.join(', '),
        product.imageUrl ?? '',
        _date(product.updatedAt),
      ]);
    }
    return rows;
  }

  /// Reads the products of a workbook.
  ///
  /// A row whose product id matches one of [existingById] updates that
  /// product; every other row creates a new one. Rows without an Arabic name,
  /// a valid price or a known category are left out and counted.
  static ProductExcelImport fromRows(
    List<List<String>> rows,
    List<AdminCategory> categories, {
    Map<String, AdminProduct> existingById = const <String, AdminProduct>{},
  }) {
    if (rows.isEmpty) {
      return const ProductExcelImport(
        products: <AdminProduct>[],
        invalidRows: 0,
        rowCount: 0,
      );
    }

    final headerIndex = <String, int>{};
    final header = rows.first;
    for (var index = 0; index < header.length; index++) {
      final name = _normalize(header[index]);
      if (name.isNotEmpty) headerIndex[name] = index;
    }

    for (final required in <String>[
      'name (arabic)',
      'base price',
    ]) {
      if (!headerIndex.containsKey(required)) {
        throw FormatException(
          'The file is missing the "${_label(required)}" column.',
        );
      }
    }

    final categoryById = <String, AdminCategory>{
      for (final category in categories) category.id: category,
    };
    final categoryByName = <String, AdminCategory>{};
    for (final category in categories) {
      for (final name in <String>[category.nameAr, category.nameEn]) {
        final key = _normalize(name);
        if (key.isNotEmpty) categoryByName[key] = category;
      }
    }

    final products = <AdminProduct>[];
    final errors = <ImportRowError>[];
    var invalidRows = 0;
    var rowCount = 0;

    for (final row in rows.skip(1)) {
      if (row.every((value) => value.trim().isEmpty)) continue;
      rowCount++;

      final nameAr = (_value(row, headerIndex, 'name (arabic)') ?? '').trim();
      final price = _double(_value(row, headerIndex, 'base price'));
      final categoryValue = (_value(row, headerIndex, 'category') ?? '').trim();
      final category = categoryValue.isEmpty
          ? null
          : _findCategory(
              categoryValue,
              categoryById,
              categoryByName,
            );

      final reasons = <String>[];
      if (nameAr.isEmpty) {
        reasons.add('Name (Arabic) is required');
      }
      if (price == null) {
        reasons.add('Base Price is required');
      } else if (price < 0) {
        reasons.add('Base Price cannot be negative');
      }
      if (categoryValue.isNotEmpty && category == null) {
        reasons.add('Category "$categoryValue" not found');
      }

      if (reasons.isNotEmpty) {
        invalidRows++;
        errors.add(
          ImportRowError(
            rowNumber: rowCount,
            productName: nameAr.isEmpty ? null : nameAr,
            reason: reasons.join(', '),
          ),
        );
        continue;
      }

      final rawId = (_value(row, headerIndex, 'product id') ?? '').trim();
      final existing = rawId.isEmpty ? null : existingById[rawId];
      var product =
          existing ??
          AdminProduct.draft(
            'draft-${DateTime.now().microsecondsSinceEpoch}-$rowCount',
          );

      product = product.copyWith(
        nameAr: nameAr,
        basePrice: price!,
        categoryId: category?.id,
        clearCategoryId: category == null,
        categoryNameAr: category?.nameAr,
        clearCategoryNameAr: category == null,
        categoryNameEn: category?.nameEn,
        clearCategoryNameEn: category == null,
      );

      final nameEn = _value(row, headerIndex, 'name (english)');
      if (nameEn != null) product = product.copyWith(nameEn: nameEn.trim());

      final sku = _value(row, headerIndex, 'sku');
      if (sku != null) product = product.copyWith(sku: sku.trim());

      final slug = _value(row, headerIndex, 'slug');
      if (slug != null) product = product.copyWith(slug: slug.trim());

      final descriptionAr = _value(row, headerIndex, 'description (arabic)');
      if (descriptionAr != null) {
        final text = descriptionAr.trim();
        product = product.copyWith(
          descriptionAr: text.isEmpty ? null : text,
          clearDescriptionAr: text.isEmpty,
        );
      }

      final descriptionEn = _value(row, headerIndex, 'description (english)');
      if (descriptionEn != null) {
        final text = descriptionEn.trim();
        product = product.copyWith(
          descriptionEn: text.isEmpty ? null : text,
          clearDescriptionEn: text.isEmpty,
        );
      }

      final compareAtPrice = _value(row, headerIndex, 'compare-at price');
      if (compareAtPrice != null) {
        final text = compareAtPrice.trim();
        product = product.copyWith(
          compareAtPrice: _double(text),
          clearCompareAtPrice: text.isEmpty,
        );
      }

      final discountPercentage = _value(
        row,
        headerIndex,
        'discount percentage',
      );
      if (discountPercentage != null) {
        final text = discountPercentage.trim();
        product = product.copyWith(
          discountPercentage: _double(text),
          clearDiscountPercentage: text.isEmpty,
        );
      }

      final discountStart = _value(row, headerIndex, 'discount start date');
      if (discountStart != null) {
        final text = discountStart.trim();
        product = product.copyWith(
          discountStartsAt: DateTime.tryParse(text),
          clearDiscountStartsAt: text.isEmpty,
        );
      }

      final discountEnd = _value(row, headerIndex, 'discount end date');
      if (discountEnd != null) {
        final text = discountEnd.trim();
        product = product.copyWith(
          discountEndsAt: DateTime.tryParse(text),
          clearDiscountEndsAt: text.isEmpty,
        );
      }

      final prepMinutes = _value(row, headerIndex, 'prep minutes');
      if (prepMinutes != null) {
        final text = prepMinutes.trim();
        product = product.copyWith(
          prepMinutes: int.tryParse(text),
          clearPrepMinutes: text.isEmpty,
        );
      }

      final calories = _value(row, headerIndex, 'calories');
      if (calories != null) {
        final text = calories.trim();
        product = product.copyWith(
          calories: int.tryParse(text),
          clearCalories: text.isEmpty,
        );
      }

      final allergens = _value(row, headerIndex, 'allergens');
      if (allergens != null) {
        product = product.copyWith(
          allergens: allergens
              .split(RegExp(r'[;,،]'))
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false),
        );
      }

      final imageUrl = _value(row, headerIndex, 'image url');
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        product = product.copyWith(imageUrl: imageUrl.trim());
      }

      final active = _value(row, headerIndex, 'active');
      if (active != null) {
        product = product.copyWith(
          isActive: _bool(active, fallback: product.isActive),
        );
      }

      final featured = _value(row, headerIndex, 'featured');
      if (featured != null) {
        product = product.copyWith(
          isFeatured: _bool(featured, fallback: product.isFeatured),
        );
      }

      products.add(product);
    }

    return ProductExcelImport(
      products: products,
      invalidRows: invalidRows,
      rowCount: rowCount,
      errors: errors,
    );
  }

  static AdminCategory? _findCategory(
    String name,
    Map<String, AdminCategory> byId,
    Map<String, AdminCategory> byName,
  ) {
    final text = name.trim();
    if (text.isEmpty) return null;
    return byId[text] ?? byName[_normalize(text)];
  }

  static String _categoryName(AdminProduct product) {
    final english = product.categoryNameEn?.trim() ?? '';
    if (english.isNotEmpty) return english;
    final arabic = product.categoryNameAr?.trim() ?? '';
    if (arabic.isNotEmpty) return arabic;
    return product.categoryId ?? '';
  }

  static String? _value(
    List<String> row,
    Map<String, int> headerIndex,
    String header,
  ) {
    final index = headerIndex[_normalize(header)];
    if (index == null || index >= row.length) return null;
    return row[index];
  }

  static double? _double(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  static bool _bool(String value, {required bool fallback}) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
      case 'نعم':
      case 'مفعل':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
      case 'لا':
      case 'معطل':
        return false;
      default:
        return fallback;
    }
  }

  static String _date(DateTime? value) {
    if (value == null) return '';
    return value.toIso8601String().split('T').first;
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _label(String header) => ProductExcelService.headers.firstWhere(
    (entry) => _normalize(entry) == header,
    orElse: () => header,
  );
}
