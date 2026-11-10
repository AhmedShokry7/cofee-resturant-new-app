import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_cubit.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_compose_dialog.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

class _FakeComposeRepository extends AdminNotificationsRepository {
  AdminNotificationDraft? sentDraft;
  AdminSendResult sendResult = const AdminSendResult(
    ok: true,
    recipients: 12,
    pushReady: 10,
  );
  AdminAudienceEstimate estimate = const AdminAudienceEstimate(
    count: 120,
    pushReady: 90,
  );

  int sendCalls = 0;

  /// Makes the bucket refuse the picture, the way it does with a file that is
  /// too big.
  bool uploadFails = false;

  /// When the test puts a completer here, a send waits for it, so the button
  /// can be pressed again while the campaign is still on its way.
  Completer<void>? sendGate;

  /// The pictures the composer pushed to the bucket, in order.
  final List<String> uploadedFileNames = <String>[];

  /// The files the composer asked to throw away again.
  final List<String> deletedImageUrls = <String>[];

  /// What the page already knows about the two channels when the composer
  /// opens — the same metrics the panel above the directory is reading.
  AdminNotificationMetrics metrics = AdminNotificationMetrics.empty;

  @override
  Future<AdminNotificationPage> loadNotifications({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    String? source,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 0,
    int pageSize = 10,
  }) async => const AdminNotificationPage();

  @override
  Future<AdminNotificationMetrics> loadMetrics() async => metrics;

  @override
  Future<AdminPushHealth> loadPushHealth() async => const AdminPushHealth();

  @override
  Future<AdminAudienceEstimate> loadAudience({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  }) async => estimate;

  @override
  Future<String> uploadCampaignImage({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (uploadFails) throw const AdminProductException('the bucket refused it');
    uploadedFileNames.add(fileName);
    return 'https://example.test/storage/v1/object/public/product-images/products/notifications/$fileName';
  }

  @override
  Future<void> deleteCampaignImageFile(String? imageUrl) async {
    if (imageUrl != null) deletedImageUrls.add(imageUrl);
  }

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
    sendCalls += 1;
    await sendGate?.future;
    sentDraft = AdminNotificationDraft(
      type: type,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
      audience: audience,
      customerId: customerId,
      imageUrl: payload['image_url'] as String?,
      destination: AdminNotificationDestination.fromValue(
        payload['destination'],
      ),
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
  AdminNotificationsCubit cubit, {
  Future<ProductImageSource?> Function()? onPickPicture,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<AdminSendResult>(
                context: context,
                builder: (_) => NotificationComposeDialog(
                  cubit: cubit,
                  onPickPicture: onPickPicture,
                ),
              ),
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

/// Opens the shared chooser and takes the device file it is offered, the way
/// the admin does: the picture button, then "upload from device".
Future<void> _attachPicture(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('notification-compose-image-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(S.uploadFromDevice));
  await tester.pumpAndSettle();
}

Future<void> _writeCampaign(WidgetTester tester) async {
  await _enter(tester, S.notificationsComposeTitleAr, 'هدية الولاء');
  await _enter(tester, S.notificationsComposeBodyAr, 'لك نقاط إضافية');
  await _enter(tester, S.notificationsComposeTitleEn, 'Loyalty gift');
  await _enter(tester, S.notificationsComposeBodyEn, 'Extra points for you');
  await tester.pumpAndSettle();
}

/// The device file the chooser is told the admin picked.
Future<ProductImageSource> _pickDevicePicture() async =>
    ProductImageSource.file(
      Uint8List.fromList(<int>[1, 2, 3]),
      'offer.png',
      'image/png',
    );

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

    await _writeCampaign(tester);

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

  testWidgets('the picked picture goes to the bucket and rides with the '
      'campaign', (tester) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository();
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit, onPickPicture: _pickDevicePicture);
    await _attachPicture(tester);

    expect(tester.takeException(), isNull);
    expect(repository.uploadedFileNames, ['offer.png']);
    expect(find.byKey(const Key('notification-compose-image')), findsOneWidget);
    expect(find.text(S.notificationsComposePreviewDeviceNote), findsOneWidget);

    await _writeCampaign(tester);
    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pumpAndSettle();

    expect(
      repository.sentDraft?.imageUrl,
      'https://example.test/storage/v1/object/public/product-images/'
      'products/notifications/offer.png',
    );
    // A campaign that went out keeps its picture: nothing is thrown away.
    expect(repository.deletedImageUrls, isEmpty);
  });

  testWidgets('a picture the bucket refuses is named and the message still '
      'sends as text', (tester) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository()..uploadFails = true;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit, onPickPicture: _pickDevicePicture);
    await _attachPicture(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('notification-compose-image')), findsNothing);

    // The chooser names the refusal and stays open for another try; the
    // message itself is not stopped by it.
    await tester.tap(
      find.descendant(
        of: find.byType(CategoryImageDialog),
        matching: find.text(S.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CategoryImageDialog), findsNothing);

    // The bar is let go before the send is pressed: it sits over the footer.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    await _writeCampaign(tester);
    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(repository.sentDraft?.imageUrl, isNull);
    expect(repository.sentDraft?.payload, isEmpty);
  });

  testWidgets('a campaign that reaches thousands is confirmed first', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository()
      ..estimate = const AdminAudienceEstimate(count: 4200, pushReady: 3900);
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit);
    await _writeCampaign(tester);

    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-compose-mass-confirm')),
      findsOneWidget,
    );
    expect(
      find.text(S.notificationsComposeMassMessage(4200, 3900)),
      findsOneWidget,
    );
    expect(repository.sendCalls, 0);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.byKey(const Key('notification-compose-mass-confirm')),
          matching: find.byType(AlertDialog),
        ),
        matching: find.text(S.cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 0);
    expect(
      find.byKey(const Key('notification-compose-dialog')),
      findsOneWidget,
    );
    expect(repository.sentDraft, isNull);

    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('notification-compose-mass-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(repository.sentDraft, isNotNull);
  });

  testWidgets('pressing send twice while a campaign goes out sends it once', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final gate = Completer<void>();
    final repository = _FakeComposeRepository()..sendGate = gate;
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit);
    await _writeCampaign(tester);

    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notification-compose-send')));
    await tester.pump();

    expect(repository.sendCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(find.byKey(const Key('notification-compose-dialog')), findsNothing);
  });

  testWidgets('closing without sending throws the picture away', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository();
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit, onPickPicture: _pickDevicePicture);
    await _attachPicture(tester);
    expect(repository.uploadedFileNames, hasLength(1));

    await tester.tap(find.byTooltip(S.close));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-compose-dialog')), findsNothing);
    expect(repository.sentDraft, isNull);
    expect(repository.deletedImageUrls, hasLength(1));
  });

  testWidgets('a refused mail channel is said before the campaign goes out', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository();
    repository.metrics = const AdminNotificationMetrics(
      emailableCustomers: 1,
      emailEnabledCustomers: 1,
      emailFailed: 2,
      emailLastError: 'resend 403: the ofoq.com domain is not verified',
    );
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit);

    expect(find.text(S.notificationsComposeMailBlocked), findsOneWidget);
  });

  testWidgets('a mail channel that reached the inbox is not doubted', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    final repository = _FakeComposeRepository();
    repository.metrics = const AdminNotificationMetrics(
      emailableCustomers: 4,
      emailEnabledCustomers: 6,
      emailSent: 3,
    );
    final cubit = AdminNotificationsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await _openComposer(tester, cubit);

    expect(find.text(S.notificationsComposeMailBlocked), findsNothing);
  });
}
