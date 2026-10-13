import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/features/notifications/data/model/notification_model.dart';

List<NotificationModel> getNotificationsList() {
  return const [
    NotificationModel(
      id: "1",
      title: "Order Shipped",
      body: "Your order #000123 is on the way. Track it now.",
      time: "2h ago",
      icon: HugeIcons.strokeRoundedTruckDelivery,
    ),
    NotificationModel(
      id: "2",
      title: "Special Offer",
      body: "Get 50% OFF on your next order. Don't miss it!",
      time: "5h ago",
      icon: HugeIcons.strokeRoundedDiscountTag01,
    ),
    NotificationModel(
      id: "3",
      title: "Order Delivered",
      body: "Your order has been delivered. Enjoy your coffee!",
      time: "1d ago",
      icon: HugeIcons.strokeRoundedTick02,
    ),
    NotificationModel(
      id: "4",
      title: "New Coupon",
      body: "A new coupon is available for you. Check it out.",
      time: "2d ago",
      icon: HugeIcons.strokeRoundedCoupon01,
    ),
  ];
}
