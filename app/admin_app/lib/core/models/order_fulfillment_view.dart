import 'package:admin_app/core/models/fulfillment_type.dart';

class OrderFulfillmentView {
  const OrderFulfillmentView(this.code, this.label);
  final String code;
  final String label;
  bool get isDelivery => code == 'delivery';

  static const allCodes = kFulfillmentCodes;

  static OrderFulfillmentView of(String code) =>
      OrderFulfillmentView(code, fulfillmentLabel(code));
}
