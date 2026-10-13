import 'package:flutter/widgets.dart';

class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}
