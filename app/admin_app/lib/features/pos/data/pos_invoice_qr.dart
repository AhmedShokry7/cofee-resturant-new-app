import 'dart:convert';

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
