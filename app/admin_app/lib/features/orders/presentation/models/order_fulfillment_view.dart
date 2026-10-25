import 'package:admin_app/core/locale/app_strings.dart';

class OrderFulfillmentView {
  const OrderFulfillmentView(this.code, this.label);
  final String code;
  final String label;
  bool get isDelivery => code == 'delivery';
  static const allCodes = <String>['delivery', 'pickup'];

  static OrderFulfillmentView of(String code) {
    final labels = <String, String>{
      'delivery': S.fulfillmentDelivery,
      'pickup': S.fulfillmentPickup,
    };
    return OrderFulfillmentView(code, labels[code] ?? S.unknownFulfillment);
  }
}
