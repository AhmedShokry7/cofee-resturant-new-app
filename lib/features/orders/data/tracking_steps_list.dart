import 'package:new_coffee/features/orders/data/model/tracking_step_model.dart';

List<TrackingStepModel> getTrackingStepsList() {
  return const [
    TrackingStepModel(title: "Order Placed", date: "23 Aug 2025", done: true),
    TrackingStepModel(title: "In Progress", date: "23 Aug 2025", done: true),
    TrackingStepModel(title: "Shipped", date: "23 Aug 2025", done: false),
    TrackingStepModel(title: "Delivered", date: "23 Aug 2025", done: false),
  ];
}
