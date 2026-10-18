import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/features/location/presentation/widgets/location_picker.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class AddAddressPageBody extends StatefulWidget {
  const AddAddressPageBody({super.key, this.address});

  final AddressModel? address;

  @override
  State<AddAddressPageBody> createState() => _AddAddressPageBodyState();
}

class _AddAddressPageBodyState extends State<AddAddressPageBody> {
  final _nameController = TextEditingController();

  /// Owned here rather than inside the picker so confirming can read it: a
  /// customer who types a place name and confirms without tapping a suggestion
  /// must still get real coordinates.
  final _searchController = TextEditingController();

  /// Null until the customer picks a spot.
  PickedLocation? _picked;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _nameController.text = address.label;
      _searchController.text = address.details;
      if (address.latitude != null && address.longitude != null) {
        _picked = PickedLocation(
          LatLng(address.latitude!, address.longitude!),
          address.details,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Turns what is on screen into a location. A pin is already a complete
  /// answer; free text is resolved only when it does not match the pin, and an
  /// unrecognised name falls back to the pin rather than discarding a
  /// deliberate choice.
  Future<PickedLocation?> _resolveLocation() async {
    final typed = _searchController.text.trim();
    final picked = _picked;
    if (typed.isEmpty) return picked;
    if (picked != null && typed == picked.label) return picked;

    try {
      final places = await context
          .read<PlaceSearchRepository>()
          .search(typed, limit: 1);
      if (!mounted || places.isEmpty) return picked;
      final resolved = PickedLocation(places.first.latLng, places.first.label);
      setState(() => _picked = resolved);
      return resolved;
    } on PlaceSearchException {
      return picked;
    }
  }

  /// A reverse-geocoded label that is only numbers is not an address, so it
  /// must never reach `customer_addresses.details`.
  static bool _looksLikeCoordinates(String value) {
    final compact = value.replaceAll(RegExp(r'[\s.,-]'), '');
    return compact.isNotEmpty && RegExp(r'^\d+$').hasMatch(compact);
  }

  Future<void> _confirm() async {
    final label = _nameController.text.trim();
    if (label.isEmpty) {
      _warn(S.addAddressName);
      return;
    }
    final picked = await _resolveLocation();
    if (!mounted) return;
    if (picked == null) {
      _warn(S.addAddressLocation);
      return;
    }
    if (_looksLikeCoordinates(picked.label)) {
      _warn(S.locationUnavailable);
      return;
    }

    final cubit = context.read<CheckoutCubit>();
    if (widget.address != null) {
      cubit.updateAddress(
        widget.address!.copyWith(
          label: label,
          details: picked.label,
          latitude: picked.point.latitude,
          longitude: picked.point.longitude,
        ),
      );
    } else {
      cubit.addAddress(
        AddressModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: label,
          details: picked.label,
          latitude: picked.point.latitude,
          longitude: picked.point.longitude,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  void _warn(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.sm.h,
            ),
            child: CustomTextFormField(
              controller: _nameController,
              hint: S.addressNameHint,
              textInputAction: TextInputAction.next,
              bottomPadding: 8,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: SpacingTokens.lg.w),
              child: LocationPicker(
                repository: context.read<PlaceSearchRepository>(),
                controller: _searchController,
                initialPoint: _picked?.point,
                onPicked: (location) => setState(() => _picked = location),
                onLocationFailure: (_) {},
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.sm.h,
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
            ),
            child: CustomBtn(text: S.confirm, onPressed: _confirm),
          ),
        ],
      ),
    );
  }
}