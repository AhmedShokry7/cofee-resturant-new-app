import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class AddAddressPageBody extends StatefulWidget {
  const AddAddressPageBody({super.key});

  @override
  State<AddAddressPageBody> createState() => _AddAddressPageBodyState();
}

class _AddAddressPageBodyState extends State<AddAddressPageBody> {
  static const LatLng _currentLocation = LatLng(16.8892, 42.5511);

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  LatLng _selectedLocation = _currentLocation;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _useCurrentLocation() {
    setState(() => _selectedLocation = _currentLocation);
    _locationController.text = "Jizan, main street";
  }

  void _confirm() {
    final label = _nameController.text.trim();
    final details = _locationController.text.trim();

    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an address name")),
      );
      return;
    }
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your location")),
      );
      return;
    }

    context.read<CheckoutCubit>().addAddress(
      AddressModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: label,
        details: details,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(SpacingTokens.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Enter your location",
                  textAlign: TextAlign.center,
                  style: AppFonts.semiBold24(context),
                ),
                SizedBox(height: SpacingTokens.xl.h),
                CustomTextFormField(
                  controller: _nameController,
                  hint: "Address name (e.g. Home)",
                  textInputAction: TextInputAction.next,
                ),
                CustomTextFormField(
                  controller: _locationController,
                  hint: "Search your location",
                  prefixIcon: Icon(
                    HugeIcons.strokeRoundedSearch01,
                    color: AppColor.greyColor,
                  ),
                  textInputAction: TextInputAction.done,
                ),
                SizedBox(height: SpacingTokens.xs.h),
                GestureDetector(
                  onTap: _useCurrentLocation,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: SpacingTokens.sm.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          HugeIcons.strokeRoundedLocation01,
                          size: 24.w,
                          color: AppColor.primaryColor,
                        ),
                        SizedBox(width: SpacingTokens.sm.w),
                        Expanded(
                          child: Text(
                            "Use my current location",
                            style: AppFonts.medium16(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                SizedBox(height: SpacingTokens.md.h),
                CustomBtn(text: "Confirm", onPressed: _confirm),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 14,
                onTap: (tapPosition, point) =>
                    setState(() => _selectedLocation = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.new_cofee',
                  tileProvider: NetworkTileProvider(
                    cachingProvider: const DisabledMapCachingProvider(),
                  ),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 40,
                      height: 40,
                      child: Icon(
                        HugeIcons.strokeRoundedLocation01,
                        size: 36.w,
                        color: AppColor.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
