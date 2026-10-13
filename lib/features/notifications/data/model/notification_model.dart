import 'package:flutter/widgets.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final IconData icon;
}
