import 'package:flutter/material.dart';

class OrderSummaryMetric {
  const OrderSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.isPositive,
    this.changeLabel,
    this.isMoney = false,
  });

  final String label, value;
  final IconData icon;
  final Color iconBackground, iconColor;
  final String? changeLabel;
  final bool isPositive;
  final bool isMoney;
}
