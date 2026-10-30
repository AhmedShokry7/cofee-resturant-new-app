import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_leave_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HrLeaveRequest _request(
  int index, {
  String status = 'pending',
  String name = 'سارة',
}) => HrLeaveRequest.fromJson(<String, dynamic>{
  'id': 'lv-$index',
  'staff_id': 's-$index',
  'staff_name': '$name $index',
  'leave_type_id': 'lt-1',
  'type_name_ar': 'إجازة سنوية',
  'starts_on': '2026-10-12',
  'ends_on': '2026-10-14',
  'days': 3,
  'reason': 'سفر',
  'status': status,
});

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  HrListState<HrLeaveRequest> state, {
  bool canReview = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeClass.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: HrLeaveView(
            state: state,
            search: '',
            status: null,
            canReview: canReview,
            onStatusChanged: (_) {},
            onApprove: (_) {},
            onReject: (_) {},
            onSetBalance: () {},
            onRetry: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a pending request offers the two decisions it can still take', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrListState<HrLeaveRequest>(
        status: HrLoadStatus.ready,
        items: <HrLeaveRequest>[_request(1)],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnApprove), findsWidgets);
    expect(find.text(S.hrActionReject), findsWidgets);
  });

  testWidgets('a decided request shows no button that the rule would refuse', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrListState<HrLeaveRequest>(
        status: HrLoadStatus.ready,
        items: <HrLeaveRequest>[_request(2, status: 'approved')],
      ),
    );

    expect(find.text(S.hrBtnApprove), findsNothing);
    expect(find.text(S.hrActionReject), findsNothing);
    // السطر نفسه يبقى مقروءًا: إخفاء الزر لا يعني إخفاء ما قررته القاعدة.
    expect(find.textContaining('سارة 2'), findsWidgets);
  });

  testWidgets('a reviewer without the permission reads the rows anyway', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrListState<HrLeaveRequest>(
        status: HrLoadStatus.ready,
        items: <HrLeaveRequest>[_request(3)],
      ),
      canReview: false,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrBtnApprove), findsNothing);
    expect(find.textContaining('سارة 3'), findsWidgets);
  });

  testWidgets(
    'a refused read that returned nothing is a failure, not emptiness',
    (tester) async {
      _setViewport(tester, 1200);
      await _pump(
        tester,
        HrListState<HrLeaveRequest>(
          status: HrLoadStatus.failure,
          failure: HrRefusal(
            sqlState: '42501',
            message: 'missing permission: hr.leave.review',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(S.hrEmptyLeave), findsNothing);
      expect(find.textContaining(S.hrMissingPermission), findsWidgets);
    },
  );

  testWidgets('a refused refresh keeps the rows already on the screen', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      HrListState<HrLeaveRequest>(
        status: HrLoadStatus.failure,
        items: <HrLeaveRequest>[_request(4, status: 'approved')],
        failure: const HrRefusal(
          sqlState: '',
          message: 'connection reset by peer',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('سارة 4'), findsWidgets);
    expect(find.textContaining('connection reset by peer'), findsWidgets);
  });

  testWidgets('narrow screens render cards without overflow', (tester) async {
    for (final width in <double>[360, 320]) {
      _setViewport(tester, width);
      await _pump(
        tester,
        HrListState<HrLeaveRequest>(
          status: HrLoadStatus.ready,
          items: <HrLeaveRequest>[
            _request(5),
            _request(6, status: 'rejected'),
          ],
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('a loaded month with no request says so in words', (
    tester,
  ) async {
    _setViewport(tester, 1200);
    await _pump(
      tester,
      const HrListState<HrLeaveRequest>(
        status: HrLoadStatus.ready,
        items: <HrLeaveRequest>[],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.hrEmptyLeave), findsOneWidget);
  });
}
