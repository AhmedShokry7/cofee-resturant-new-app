import 'package:admin_app/shared/widgets/admin_metric_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// شبكة المقاييس لا تعرض أبدًا «٣ جنبًا وبطاقة نازلة وحدها»:
/// أربع بطاقات تعرض صفًّا واحدًا على العرض الواسع، وصفّين متساويين
/// (٢×٢) على التابليت، وعمودًا واحدًا على الهاتف.
void main() {
  Future<List<double>> tileWidths(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: AdminMetricGrid(
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(height: 60, child: ColoredBox(color: Colors.primaries[i])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tiles = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(AdminMetricGrid),
            matching: find.byType(SizedBox),
          ),
        )
        .where((t) => t.width != null)
        .toList();
    return tiles.map((t) => t.width ?? 0).toList();
  }

  testWidgets('عرض واسع: البطاقات الأربع في صف واحد متساوٍ', (tester) async {
    final widths = await tileWidths(tester, 1200);
    expect(widths.length, 4);
    expect(widths.every((w) => (w - widths.first).abs() < 0.5), isTrue);
    // صف واحد: كل بطاقة ≈ (1200 - 3×13) / 4.
    expect((widths.first - (1200 - 39) / 4).abs() < 1, isTrue);
  });

  testWidgets('تابليت: صفّان ٢×٢ بلا بطاقة نازلة وحدها', (tester) async {
    final widths = await tileWidths(tester, 800);
    expect(widths.length, 4);
    expect(widths.every((w) => (w - widths.first).abs() < 0.5), isTrue);
    // عمودان: كل بطاقة ≈ نصف العرض.
    expect((widths.first - (800 - 13) / 2).abs() < 1, isTrue);
  });

  testWidgets('هاتف صغير: عمود واحد', (tester) async {
    final widths = await tileWidths(tester, 400);
    expect(widths.length, 4);
    expect(widths.every((w) => (w - 400).abs() < 0.5), isTrue);
  });
}
