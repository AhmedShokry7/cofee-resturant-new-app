import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';

/// The steps of writing a picture.
///
/// The file is sent to the bucket first and the row of the picture is written
/// afterwards, so the dashboard can tell the admin which step is running.
enum AdminImageUploadPhase {
  /// The file is on its way to the bucket.
  uploading,

  /// The file is in the bucket and the row of the picture is written.
  saving,
}

/// Where a picture of a product comes from.
///
/// The admin can pick a file from the device (it is uploaded to the bucket
/// of the catalogue) or use a link that is already hosted somewhere.
class ProductImageSource {
  const ProductImageSource.link(this.url)
    : bytes = null,
      fileName = null,
      contentType = null;

  const ProductImageSource.file(this.bytes, this.fileName, this.contentType)
    : url = null;

  /// The picture that is already hosted somewhere.
  final String? url;

  /// The file the admin picked from the device.
  final Uint8List? bytes;
  final String? fileName;
  final String? contentType;

  bool get isLink => url != null;
}

/// A picture that belongs to a product.
///
/// The row mirrors `catalog.product_images`: the picture itself is a public
/// url, the order of the pictures is kept by [sortOrder] and exactly one
/// picture of a product is the primary one.
///
/// Every picture carries its own display settings: [fit] says how it fills
/// its space and [alignment] where it sits in it. The settings change only
/// the way the picture is shown, never the file itself.
class AdminProductImage {
  const AdminProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.altAr,
    this.altEn,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String id;
  final String productId;
  final String imageUrl;
  final String? altAr;
  final String? altEn;
  final int sortOrder;

  /// True for the picture the cards and the lists show.
  final bool isPrimary;

  /// How the picture fills its space.
  final BoxFit fit;

  /// Where the picture sits in its space.
  final Alignment alignment;

  factory AdminProductImage.fromRow(Map<String, dynamic> row) {
    return AdminProductImage(
      id: '${row['id'] ?? ''}',
      productId: '${row['product_id'] ?? ''}',
      imageUrl: '${row['image_url'] ?? ''}',
      altAr: row['alt_ar'] as String?,
      altEn: row['alt_en'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isPrimary: row['is_primary'] == true,
      fit: fitFromName(row['fit'] as String?),
      alignment: alignmentFromName(row['alignment'] as String?),
    );
  }

  AdminProductImage copyWith({
    String? imageUrl,
    int? sortOrder,
    bool? isPrimary,
    BoxFit? fit,
    Alignment? alignment,
  }) {
    return AdminProductImage(
      id: id,
      productId: productId,
      imageUrl: imageUrl ?? this.imageUrl,
      altAr: altAr,
      altEn: altEn,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
    );
  }

  /// The caption of the picture in the language of the admin panel.
  String altFor(AppLanguage language) {
    final text = language.isArabic ? altAr : altEn;
    if (text != null && text.trim().isNotEmpty) return text;
    return '';
  }
}

/// The ways a picture can fill its space, with the names the database uses.
const List<BoxFit> imageFitOptions = <BoxFit>[
  BoxFit.cover,
  BoxFit.contain,
  BoxFit.fill,
  BoxFit.fitWidth,
  BoxFit.fitHeight,
  BoxFit.scaleDown,
  BoxFit.none,
];

/// The places a picture can sit in its space, with the names the database
/// uses.
const List<Alignment> imageAlignmentOptions = <Alignment>[
  Alignment.center,
  Alignment.topCenter,
  Alignment.topLeft,
  Alignment.topRight,
  Alignment.centerLeft,
  Alignment.centerRight,
  Alignment.bottomLeft,
  Alignment.bottomCenter,
  Alignment.bottomRight,
];

/// The name of a way to fill the space, as the database stores it.
String fitName(BoxFit fit) => fit.name;

/// The name of a place in the space, as the database stores it.
String alignmentName(Alignment alignment) {
  if (alignment == Alignment.topLeft) return 'topLeft';
  if (alignment == Alignment.topCenter) return 'topCenter';
  if (alignment == Alignment.topRight) return 'topRight';
  if (alignment == Alignment.centerLeft) return 'centerLeft';
  if (alignment == Alignment.centerRight) return 'centerRight';
  if (alignment == Alignment.bottomLeft) return 'bottomLeft';
  if (alignment == Alignment.bottomCenter) return 'bottomCenter';
  if (alignment == Alignment.bottomRight) return 'bottomRight';
  return 'center';
}

/// The way to fill the space, with a safe default for the pictures that have
/// no settings yet.
BoxFit fitFromName(String? name) {
  for (final fit in imageFitOptions) {
    if (fit.name == name) return fit;
  }
  return BoxFit.cover;
}

/// The place in the space, with a safe default for the pictures that have no
/// settings yet.
Alignment alignmentFromName(String? name) {
  for (final alignment in imageAlignmentOptions) {
    if (alignmentName(alignment) == name) return alignment;
  }
  return Alignment.center;
}
