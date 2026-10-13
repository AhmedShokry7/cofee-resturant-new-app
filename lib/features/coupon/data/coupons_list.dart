import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

List<CouponModel> getCouponsList() {
  return const [
    CouponModel(
      id: "1",
      code: "WELCOME200",
      title: "WELCOME 200",
      description: "Add items worth 2 more to unlock",
      discount: "Get 50% OFF",
    ),
    CouponModel(
      id: "2",
      code: "COFFEE20",
      title: "COFFEE 20",
      description: "On your first order this week",
      discount: "Get 20% OFF",
    ),
    CouponModel(
      id: "3",
      code: "COLD50",
      title: "COLD DRINKS",
      description: "Valid on all iced drinks today",
      discount: "Get 50% OFF",
    ),
    CouponModel(
      id: "4",
      code: "LOYAL10",
      title: "LOYALTY",
      description: "For our frequent coffee lovers",
      discount: "Get 10% OFF",
    ),
  ];
}
