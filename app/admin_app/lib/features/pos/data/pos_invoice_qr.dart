import 'dart:convert';

import 'package:qr/qr.dart';

/// The five ZATCA Phase 1 tags of the simplified tax invoice QR.
const int posQrSellerNameTag = 1;
const int posQrVatNumberTag = 2;
const int posQrTimestampTag = 3;
const int posQrTotalTag = 4;
const int posQrVatAmountTag = 5;

/// Builds the Base64 TLV payload ZATCA expects in the QR of a simplified tax
/// invoice: seller name, VAT number, ISO 8601 timestamp, total and VAT amount.
String buildPosInvoiceQrData({
  required String sellerName,
  required String vatNumber,
  required String timestamp,
  required String total,
  required String vatAmount,
}) {
  final bytes = <int>[
    ..._tlv(posQrSellerNameTag, sellerName),
    ..._tlv(posQrVatNumberTag, vatNumber),
    ..._tlv(posQrTimestampTag, timestamp),
    ..._tlv(posQrTotalTag, total),
    ..._tlv(posQrVatAmountTag, vatAmount),
  ];
  return base64Encode(bytes);
}

List<int> _tlv(int tag, String value) {
  final bytes = utf8.encode(value.trim());
  if (bytes.length > 255) {
    throw ArgumentError('ZATCA QR tag $tag exceeds 255 bytes');
  }
  return <int>[tag, bytes.length, ...bytes];
}

/// Renders [data] as an inline SVG QR code for the print document.
String renderPosQrSvg(String data, {int moduleSize = 4, int quietZone = 4}) {
  final code = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final image = QrImage(code);
  final count = image.moduleCount;
  final size = (count + quietZone * 2) * moduleSize;
  final path = StringBuffer();
  for (var row = 0; row < count; row++) {
    for (var column = 0; column < count; column++) {
      if (!image.isDark(row, column)) continue;
      final x = (column + quietZone) * moduleSize;
      final y = (row + quietZone) * moduleSize;
      path.write('M$x ${y}h${moduleSize}v${moduleSize}h-${moduleSize}z');
    }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
      'viewBox="0 0 $size $size" shape-rendering="crispEdges" role="img">'
      '<rect width="$size" height="$size" fill="#ffffff"/>'
      '<path d="${path.toString()}" fill="#000000"/></svg>';
}
