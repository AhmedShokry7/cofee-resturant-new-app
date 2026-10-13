import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/addresses_list.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/payment_methods_list.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit()
      : super(
          CheckoutState(
            addresses: getAddressesList(),
            selectedAddress: getAddressesList().first,
            paymentMethods: getPaymentMethodsList(),
            selectedPaymentMethod: getPaymentMethodsList().last,
          ),
        );

  void selectAddress(AddressModel address) {
    emit(state.copyWith(selectedAddress: address));
  }

  void addAddress(AddressModel address) {
    emit(
      state.copyWith(
        addresses: [...state.addresses, address],
        selectedAddress: address,
      ),
    );
  }

  void selectPaymentMethod(PaymentMethodModel method) {
    emit(state.copyWith(selectedPaymentMethod: method));
  }

  void placeOrder({required List<CartItem> items, required double total}) {
    final number = DateTime.now().millisecondsSinceEpoch % 1000000;
    emit(
      state.copyWith(
        lastOrder: OrderModel(
          id: "#${number.toString().padLeft(6, '0')}",
          date: DateTime.now(),
          items: items,
          total: total,
        ),
      ),
    );
  }
}
