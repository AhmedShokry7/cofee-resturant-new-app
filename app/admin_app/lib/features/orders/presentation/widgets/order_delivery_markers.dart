import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';

class OrderDeliveryMarkers extends StatelessWidget {
  const OrderDeliveryMarkers({super.key, required this.delivery, this.branch});

  final LatLng delivery;
  final LatLng? branch;

  @override
  Widget build(BuildContext context) => MarkerLayer(
    markers: [
      if (branch != null)
        Marker(
          point: branch!,
          width: 40,
          height: 40,
          child: const AppIcon(
            AppIcons.store01,
            size: 30,
            color: AppColor.primaryColor,
          ),
        ),
      Marker(
        point: delivery,
        width: 40,
        height: 40,
        child: const AppIcon(
          AppIcons.mapPin,
          size: 36,
          color: AppColor.errorColor,
        ),
      ),
    ],
  );
}
