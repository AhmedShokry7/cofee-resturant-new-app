import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/admin_donut_chart.dart';
import 'package:admin_app/shared/widgets/admin_panel_row.dart';
import 'package:admin_app/shared/widgets/admin_reveal.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_geometry.dart';

Widget _wrap(Widget child, {bool reduced = false, double? width}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: width == null ? child : SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  group('trend geometry', () {
    test('the series is placed by its own range, tallest at the top', () {
      final points = trendPointPositions(
        values: const [10, 40, 20],
        size: const Size(100, 50),
        progress: 1,
        margin: 0,
      );

      expect(points.first.dx, 0);
      expect(points.last.dx, 100);
      // المقياس من الصفر لا من أدنى قيمة: أعلى قيمة تلمس الحافة العليا
      // ونصفها يقف في منتصف المسافة منها إلى الخط، فتبقى النسبة مقروءة.
      expect(points[1].dy, 0);
      expect(points.first.dy, 37.5);
      expect(points[2].dy, 25);
    });

    test('a flat series is centred instead of dividing by a zero range', () {
      final points = trendPointPositions(
        values: const [25, 25, 25],
        size: const Size(100, 50),
        progress: 1,
        margin: 0,
      );

      expect(points.every((point) => point.dy == 25), isTrue);
    });

    test('a zero-progress series sits on its baseline', () {
      final points = trendPointPositions(
        values: const [10, 40],
        size: const Size(100, 50),
        progress: 0,
        margin: 0,
      );

      expect(points.every((point) => point.dy == 50), isTrue);
    });

    test('the smooth path walks every point in order', () {
      final path = smoothTrendPath(const [
        Offset(0, 10),
        Offset(20, 4),
        Offset(40, 12),
      ]);

      expect(path.getBounds().left, 0);
      expect(path.getBounds().right, 40);
    });
  });

  group('shared chart widgets', () {
    testWidgets('a trend with axis labels renders and reveals once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AdminTrendChart(
            points: const [
              AdminTrendPoint(label: '1', value: 10),
              AdminTrendPoint(label: '2', value: 40),
              AdminTrendPoint(label: '3', value: 25),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('reduced motion draws the final frame without a tween', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AdminTrendChart(
            points: const [
              AdminTrendPoint(label: 'a', value: 1),
              AdminTrendPoint(label: 'b', value: 2),
            ],
          ),
          reduced: true,
        ),
      );
      await tester.pump();

      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a donut prints its centre number and label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminDonutChart(
            slices: [
              AdminDonutSlice(
                label: 'pickup',
                value: 3,
                color: AppColor.primaryColor,
              ),
              AdminDonutSlice(
                label: 'dine_in',
                value: 1,
                color: AppColor.adminRowBorder,
              ),
            ],
            centerValue: '4',
            centerLabel: 'Orders',
          ),
          reduced: true,
        ),
      );
      await tester.pump();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the segmented control reports the option the admin pressed', (
      tester,
    ) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _wrap(
          AdminSegmentedControl(
            options: const ['seven', 'thirty'],
            selected: 'thirty',
            onChanged: asked.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('seven'));
      await tester.pumpAndSettle();
      expect(asked, <String>['seven']);

      // الضغط على الخيار النشط لا يستدعي أحدًا: لا عمل يُعاد بلا سبب.
      await tester.tap(find.text('thirty'));
      await tester.pumpAndSettle();
      expect(asked, <String>['seven']);
    });

    testWidgets('a panel row takes the width it is given, not the window', (
      tester,
    ) async {
      // النافذة أوسع من المقاسين حتى يكون الحيز المتاح هو الذي يُقاس،
      // لا سقف الاختبار الافتراضي الذي كان يجعل الحالتين واحدة.
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget board(double width) => _wrap(
        const AdminPanelRow(
          children: [SizedBox(height: 40), SizedBox(height: 40)],
        ),
        width: width,
      );

      await tester.pumpWidget(board(AppBreakpoints.wideLayout));
      await tester.pumpAndSettle();
      expect(find.byType(Row), findsOneWidget);

      await tester.pumpWidget(board(AppBreakpoints.wideLayout - 1));
      await tester.pumpAndSettle();
      expect(find.byType(Row), findsNothing);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('a reveal under reduced motion is already on screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminReveal(
            index: 3,
            child: Text('card', key: Key('revealed')),
          ),
          reduced: true,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('revealed')), findsOneWidget);
      // الهدف الظاهر فورًا: لا تدرّج لمن أوقف الحركة في جهازه.
      expect(_revealOpacity(tester), 1);
      expect(_revealOffset(tester), Offset.zero);
    });

    testWidgets('a reveal waits its turn then arrives', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminReveal(index: 2, child: Text('card', key: Key('later'))),
        ),
      );
      await tester.pump();

      expect(_revealOpacity(tester), 0);

      await tester.pump(AppDimensions.revealStepDelay * 2);
      await tester.pumpAndSettle();

      expect(_revealOpacity(tester), 1);
      expect(_revealOffset(tester), Offset.zero);
    });
  });
}

/// اللوحة لم تظهر بعد: القيمة المستهدفة في `AnimatedOpacity` لا الناتجة منها.
double _revealOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

Offset _revealOffset(WidgetTester tester) =>
    tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset;
