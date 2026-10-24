import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// The map that shows where the order should be delivered.
class OrderDeliveryMap extends StatelessWidget {
  const OrderDeliveryMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.branchLatitude,
    this.branchLongitude,
  });

  final double latitude;
  final double longitude;
  final double? branchLatitude;
  final double? branchLongitude;

  double? get _distanceKm {
    final blat = branchLatitude;
    final blng = branchLongitude;
    if (blat == null || blng == null) return null;
    return _haversineKm(blat, blng, latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deliveryPoint = LatLng(latitude, longitude);
    final branchPoint = (branchLatitude != null && branchLongitude != null)
        ? LatLng(branchLatitude!, branchLongitude!)
        : null;
    final distance = _distanceKm;
    final minutes = distance == null ? null : (distance / 30 * 60 + 5).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.deliveryLocation,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: deliveryPoint,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'admin_app',
              ),
              if (branchPoint != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [branchPoint, deliveryPoint],
                      strokeWidth: 3,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (branchPoint != null)
                    Marker(
                      point: branchPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.store,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                  Marker(
                    point: deliveryPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (distance != null) ...[
          const SizedBox(height: AppDimensions.sm),
          Text(
            '${S.deliveryDistance}: ${distance.toStringAsFixed(1)} km  •  '
            '${S.estimatedDelivery}: $minutes min',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
        ] else ...[
          const SizedBox(height: AppDimensions.sm),
          Text(
            S.branchLocationUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
        ],
      ],
    );
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);
}