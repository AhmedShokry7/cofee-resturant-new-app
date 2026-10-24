import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';

class CheckoutBottomBar extends StatelessWidget {
  const CheckoutBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      buildWhen: (previous, current) =>
          previous.addressOutOfZone != current.addressOutOfZone ||
          previous.isResolvingZone != current.isResolvingZone ||
          previous.checkoutQuote != current.checkoutQuote ||
          previous.quoteLoading != current.quoteLoading ||
          previous.quoteError != current.quoteError ||
          previous.deliveryBlocked != current.deliveryBlocked ||
          previous.selectedDeliveryZone != current.selectedDeliveryZone,
      builder: (context, state) => PrimaryBottomBar(
        text: S.continueToPayment,
        enabled:
            !state.addressOutOfZone &&
            !state.isResolvingZone &&
            !state.deliveryBlocked &&
            !state.quoteLoading &&
            state.checkoutQuote != null &&
            state.quoteError == null &&
            (!state.fulfillment.isDelivery ||
                state.selectedDeliveryZone != null),
        onPressed: () =>
            Navigator.of(context).pushNamed(PaymentMethodPage.routeName),
      ),
    );
  }
}
