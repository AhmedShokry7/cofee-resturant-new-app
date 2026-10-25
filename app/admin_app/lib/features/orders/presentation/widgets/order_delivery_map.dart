import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_delivery_estimate.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_distance_calculator.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_delivery_markers.dart';

class OrderDeliveryMap extends StatelessWidget {
  const OrderDeliveryMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.branchLatitude,
    this.branchLongitude,
  });
  final double latitude, longitude;
  final double? branchLatitude, branchLongitude;

  @override
  Widget build(BuildContext context) {
    final delivery = LatLng(latitude, longitude);
    final branch = branchLatitude == null || branchLongitude == null
        ? null
        : LatLng(branchLatitude!, branchLongitude!);
    final distance = branch == null
        ? null
        : OrderDistanceCalculator.kilometers(
            branch.latitude,
            branch.longitude,
            delivery.latitude,
            delivery.longitude,
          );
    final height = (MediaQuery.sizeOf(context).height * .45)
        .clamp(240.0, 420.0)
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.deliveryLocation,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimensions.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: SizedBox(
            height: height,
            child: FlutterMap(
              options: MapOptions(initialCenter: delivery, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'admin_app',
                ),
                if (branch != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [branch, delivery],
                        strokeWidth: 3,
                        color: AppColor.primaryColor,
                      ),
                    ],
                  ),
                OrderDeliveryMarkers(branch: branch, delivery: delivery),
              ],
            ),
          ),
        ),
        OrderDeliveryEstimate(distanceKm: distance),
      ],
    );
  }
}
