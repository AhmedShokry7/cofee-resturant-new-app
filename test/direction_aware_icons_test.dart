import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';

/// Pumps a [Directionality] with the given [textDirection] and reports which
/// glyph [DirectionAwareIcons] resolves for back and forward.
Future<void> _probe(
  WidgetTester tester, {
  required TextDirection textDirection,
  required void Function(IconData back, IconData forward) onResolved,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: textDirection,
      child: Builder(
        builder: (context) {
          onResolved(
            DirectionAwareIcons.back(context),
            DirectionAwareIcons.forward(context),
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectionAwareIcons resolves the logical reading direction', () {
    testWidgets('back points left and forward points right in LTR (English)', (
      tester,
    ) async {
      await _probe(
        tester,
        textDirection: TextDirection.ltr,
        onResolved: (back, forward) {
          expect(
            back,
            AppIcons.back,
            reason: 'logical back must point left in LTR',
          );
          expect(
            forward,
            AppIcons.forward,
            reason: 'logical forward must point right in LTR',
          );
        },
      );
    });

    testWidgets('back points right and forward points left in RTL (Arabic)', (
      tester,
    ) async {
      await _probe(
        tester,
        textDirection: TextDirection.rtl,
        onResolved: (back, forward) {
          expect(
            back,
            AppIcons.forward,
            reason: 'logical back must point right in RTL',
          );
          expect(
            forward,
            AppIcons.back,
            reason: 'logical forward must point left in RTL',
          );
        },
      );
    });

    testWidgets('back and forward are distinct glyphs in both locales', (
      tester,
    ) async {
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        await _probe(
          tester,
          textDirection: direction,
          onResolved: (back, forward) {
            expect(back, isNot(forward));
          },
        );
      }
    });
  });
}
