import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_cubit.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_compose_dialog.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

class _FakeComposeRepository extends AdminNotificationsRepository {
  AdminNotificationDraft? sentDraft;
  AdminSendResult sendResult = const AdminSendResult(
    ok: true,
    recipients: 12,
    pushReady: 10,
  );

  @override
  Future<AdminNotificationPage> loadNotifications({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    int page = 0,
    int pageSize = 10,
  }) async => const AdminNotificationPage();

  @override
  Future<AdminNotificationMetrics> loadMetrics() async =>
      AdminNotificationMetrics.empty;

  @override
  Future<AdminPushHealth> loadPushHealth() async => const AdminPushHealth();

  @override
  Future<AdminAudienceEstimate> loadAudience({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  }) async => const AdminAudienceEstimate(count: 120, pushReady: 90);

  @override
  Future<AdminSendResult> sendNotification({
    required AdminNotificationType type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required AdminNotificationAudience audience,
    String? customerId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    sentDraft = AdminNotificationDraft(
      type: type,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
      audience: audience,
      customerId: customerId,
      payload: payload,
    );
    return sendResult;
  }
}

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openComposer(
  WidgetTester tester,
  AdminNotificationsCubit cubit,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showNotificationComposeDialog(context: context, cubit: cubit),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.ancestor(
    of: find.text(label),
    matching: find.byType(CustomTextFormField),
  );
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(TextFormField)),
    value,
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a bilingual campaign is sent and the dialog closes', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository();
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit);

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('notification-compose-dialog')),
      findsOneWidget,
    );
    expect(find.text(S.notificationsComposeEstimateValue(120)), findsOneWidget);
    expect(find.text(S.notificationsComposeEstimatePush(90)), findsOneWidget);

    await _enter(tester, S.notificationsComposeTitleAr, 'هدية الولاء');
    await _enter(tester, S.notificationsComposeBodyAr, 'لك نقاط إضافية');
    await _enter(tester, S.notificationsComposeTitleEn, 'Loyalty gift');
    await _enter(tester, S.notificationsComposeBodyEn, 'Extra points for you');
    await tester.pumpAndSettle();

    expect(find.text('Loyalty gift'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('notification-compose-dialog')), findsNothing);
    expect(repository.sentDraft, isNotNull);
    expect(repository.sentDraft?.type, AdminNotificationType.promo);
    expect(repository.sentDraft?.audience, AdminNotificationAudience.all);
    expect(repository.sentDraft?.titleAr, 'هدية الولاء');
    expect(repository.sentDraft?.titleEn, 'Loyalty gift');
    expect(repository.sentDraft?.bodyAr, 'لك نقاط إضافية');
    expect(repository.sentDraft?.bodyEn, 'Extra points for you');
  });

  testWidgets('empty fields block the send and explain what is needed', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository();
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit);
    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('notification-compose-dialog')),
      findsOneWidget,
    );
    expect(find.text(S.requiredField), findsNWidgets(4));
    expect(repository.sentDraft, isNull);
  });
}
