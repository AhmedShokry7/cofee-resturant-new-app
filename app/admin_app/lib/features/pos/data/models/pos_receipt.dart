import 'package:admin_app/features/pos/data/models/pos_cart.dart';
import 'package:admin_app/features/pos/data/models/pos_order_result.dart';

/// The finalized sale the receipt dialog and the printout present.
class PosReceipt {
  const PosReceipt({
    required this.result,
    this.lines = const <PosCartLine>[],
    this.note = '',
  });

  final PosOrderResult result;
  final List<PosCartLine> lines;
  final String note;

  String get orderNumber => result.orderNumber;

  String get currencyCode => result.currencyCode;

  String get orderNote => note.trim();

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}
