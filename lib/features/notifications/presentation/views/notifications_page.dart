import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/notifications/data/notifications_list.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const routeName = "notificationsRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: ListView(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        children: getNotificationsList()
            .map((notification) => NotificationTile(notification: notification))
            .toList(),
      ),
    );
  }
}
