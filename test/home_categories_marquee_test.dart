import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_circle_item.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_marquee.dart';

/// The chips the row is given, in the order home would hand them over.
///
/// Each carries a stable id: `CategoryModel` compares itself by id, so fixtures
/// without one would all be the same category.
List<CategoryModel> chips(int count) => List.generate(
  count,
  (index) => CategoryModel(
    id: 'category-$index',
    label: 'category-$index',
    icon: Icons.grid_view,
  ),
);

/// The row the way the home page holds it: a child of a `Column`, so a bounded
/// width and a height it decides for itself.
Future<void> pumpRow(
  WidgetTester tester,
  List<CategoryModel> categories, {
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
  void Function(CategoryModel category)? onTap,
}) async {
  tester.view.physicalSize = const Size(360, 690) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: textScaler,
                disableAnimations: reduceMotion,
              ),
              child: Column(
                children: [
                  CategoryMarquee(
                    categories: categories,
                    onTap: onTap ?? (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Where the row currently stands along its own content.
double rowOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(CategoryMarquee),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

/// The names the row laid out, in the order it laid them out.
List<String> chipLabels(WidgetTester tester) => tester
    .widgetList<CategoryCircleItem>(find.byType(CategoryCircleItem))
    .map((chip) => chip.category.label)
    .toList();

/// Takes the row out of the tree so its ticker and its resume timer die with
/// the test: a repeating animation that outlives it fails the next one.
Future<void> retire(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// How far the row sits from a whole number of turns, in pixels.
///
/// The walk restarts its loop at the boundary, and the clock rounds, so a test
/// that cares about "one turn later" asks about the boundary rather than about
/// which side of it the frame landed on.
double offTurn(WidgetTester tester, double cycle) {
  final turns = rowOffset(tester) / cycle;
  return (turns - turns.roundToDouble()).abs() * cycle;
}

void main() {
  group('Home category row', () {
    testWidgets('it walks on its own, at a speed a name can be read at', (
      tester,
    ) async {
      await pumpRow(tester, chips(5));
      expect(rowOffset(tester), 0);

      await tester.pump(const Duration(seconds: 1));

      final moved = rowOffset(tester);
      expect(moved, greaterThan(0));
      // Never faster than one chip a second, or the labels stop being readable
      // while they pass.
      expect(moved, lessThan(CategoryCircleItem.slot));
      await retire(tester);
    });

    testWidgets('the chips behind the screen repeat the ones on it', (
      tester,
    ) async {
      const count = 5;
      await pumpRow(tester, chips(count));

      final labels = chipLabels(tester);
      // More chips than categories: the row never runs out in front of the
      // customer.
      expect(labels.length, greaterThan(count));
      // And one turn later is the same list again, which is what lets the walk
      // roll into its next turn without a seam.
      for (var index = 0; index + count < labels.length; index++) {
        expect(labels[index + count], labels[index]);
      }
      await retire(tester);
    });

    testWidgets('one full turn lands on the boundary it started from', (
      tester,
    ) async {
      const count = 5;
      const cycle = count * CategoryCircleItem.slot;
      await pumpRow(tester, chips(count));

      // Half a turn: the row sits half a cycle along, so it walks steadily
      // rather than in jumps.
      await tester.pump(CategoryMarquee.turnFor(count) * 0.5);
      expect(rowOffset(tester), closeTo(cycle / 2, 1));

      // A whole turn brings it back to a cycle boundary. The chips repeat every
      // boundary, so the picture there is the one the row started with - which
      // is what makes the wrap invisible.
      await tester.pump(CategoryMarquee.turnFor(count) * 0.5);
      expect(offTurn(tester, cycle), lessThan(1.0));
      await retire(tester);
    });

    testWidgets('a finger holds the row still and it starts again after', (
      tester,
    ) async {
      await pumpRow(tester, chips(5));
      await tester.pump(const Duration(seconds: 1));
      final walking = rowOffset(tester);
      expect(walking, greaterThan(0));

      // A finger on the row: it answers to them, not to its own clock.
      final gesture = await tester.startGesture(const Offset(180, 40));
      await tester.pump(const Duration(seconds: 1));
      expect(rowOffset(tester), walking);

      await gesture.up();

      // The pause outlasts the touch: they stopped it to read a name.
      await tester.pump(MotionTokens.marqueeResumeHold);
      expect(rowOffset(tester), walking);

      // Then it carries on, from the chip it was left on and at the same speed,
      // not back at the start of the loop.
      await tester.pump(const Duration(seconds: 1));
      expect(
        rowOffset(tester),
        closeTo(walking + CategoryMarquee.pixelsPerSecond, 1),
      );
      await retire(tester);
    });

    testWidgets('the customer can swipe it like any other row', (tester) async {
      await pumpRow(tester, chips(5));
      final before = rowOffset(tester);

      await tester.drag(find.byType(ListView), const Offset(-100, 0));
      await tester.pump();

      expect(rowOffset(tester), greaterThan(before));
      await retire(tester);
    });

    testWidgets('reduce-motion leaves the row where it is', (tester) async {
      await pumpRow(tester, chips(5), reduceMotion: true);

      await tester.pump(const Duration(seconds: 2));

      expect(rowOffset(tester), 0);
      // The categories are still there to read and to swipe by hand.
      expect(find.byType(CategoryCircleItem), findsWidgets);
      await retire(tester);
    });

    testWidgets('a single category is not repeated and does not walk', (
      tester,
    ) async {
      await pumpRow(tester, chips(1));

      expect(find.byType(CategoryCircleItem), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(rowOffset(tester), 0);
      await retire(tester);
    });

    testWidgets('every chip sits on the same line', (tester) async {
      await pumpRow(tester, chips(5));

      final chipsOnScreen = find.byType(CategoryCircleItem);
      final lines = <double>{};
      for (var index = 0; index < chipsOnScreen.evaluate().length; index++) {
        lines.add(tester.getTopLeft(chipsOnScreen.at(index)).dy);
      }
      // One row, the way home shows them now.
      expect(lines, hasLength(1));
      await retire(tester);
    });

    testWidgets('a press names the chip that was under the finger', (
      tester,
    ) async {
      final tapped = <CategoryModel>[];
      await pumpRow(tester, chips(5), onTap: tapped.add);

      await tester.tap(find.byType(CategoryCircleItem).first);
      await tester.pump();

      expect(tapped, hasLength(1));
      expect(tapped.single.label, chipLabels(tester).first);
      await retire(tester);
    });

    testWidgets('a larger text size grows the row instead of cutting names', (
      tester,
    ) async {
      await pumpRow(tester, chips(5));
      final normal = tester.getSize(find.byType(CategoryMarquee)).height;

      await pumpRow(tester, chips(5), textScaler: const TextScaler.linear(3));

      // No overflow: the row makes room for the type the customer chose.
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(CategoryMarquee)).height,
        greaterThan(normal),
      );
      await retire(tester);
    });

    testWidgets('the row walks the same way right-to-left', (tester) async {
      await pumpRow(tester, chips(5), direction: TextDirection.rtl);

      // The first chip starts at the reading edge, not the left one.
      expect(tester.getRect(find.byType(CategoryCircleItem).first).right, 360);

      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(rowOffset(tester), greaterThan(0));
      await retire(tester);
    });

    testWidgets('no categories leaves nothing on the page', (tester) async {
      await pumpRow(tester, const []);

      expect(find.byType(CategoryCircleItem), findsNothing);
      expect(tester.takeException(), isNull);
      await retire(tester);
    });
  });
}
