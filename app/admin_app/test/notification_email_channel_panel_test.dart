import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_email_channel_panel.dart';

Future<void> _pump(
  WidgetTester tester,
  AdminNotificationMetrics metrics, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(1200, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: SingleChildScrollView(
            child: NotificationEmailChannelPanel(metrics: metrics),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('NotificationEmailChannelPanel', () {
    testWidgets('a provider refusal is printed in its own words', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdminNotificationMetrics(
          emailEnabledCustomers: 4,
          emailableCustomers: 0,
          emailSkipped: 2,
          emailLastError: 'resend 403: the ofoq.com domain is not verified',
        ),
      );

      expect(find.text(S.notificationsEmailTitle), findsOneWidget);
      expect(find.text(S.notificationsEmailBlocked), findsOneWidget);
      expect(
        find.textContaining('resend 403: the ofoq.com domain is not verified'),
        findsOneWidget,
      );
      expect(find.text(S.notificationsEmailNoTargetHint), findsOneWidget);
    });

    testWidgets('a channel that reached inboxes reads ready and stays quiet', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdminNotificationMetrics(
          emailEnabledCustomers: 40,
          emailableCustomers: 37,
          emailSent: 24,
          emailSuccessRate: 100,
        ),
      );

      expect(find.text(S.notificationsEmailReady), findsOneWidget);
      expect(
        find.textContaining('No mail attempts recorded yet'),
        findsNothing,
      );
      expect(find.textContaining('37 mailable addresses'), findsOneWidget);
    });

    testWidgets('the panel draws in Arabic and in the dark theme', (
      tester,
    ) async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      await _pump(
        tester,
        const AdminNotificationMetrics(emailableCustomers: 2),
        dark: true,
        direction: TextDirection.rtl,
      );

      expect(find.text('قناة البريد الإلكتروني'), findsOneWidget);
      expect(find.text(S.notificationsEmailIdle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
