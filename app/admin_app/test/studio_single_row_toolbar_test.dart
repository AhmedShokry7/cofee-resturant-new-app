import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/studio_single_row_toolbar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements VisualEditorRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final direction in TextDirection.values) {
    for (final width in [390.0, 1024.0, 1440.0, 1920.0]) {
      testWidgets('single row at $width in $direction', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cubit = VisualEditorCubit(repository: _Repository());
        addTearDown(cubit.close);
        PreviewDevice? selectedDevice;
        String? selectedPage;
        bool? selectedMode;
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: StudioSingleRowToolbar(
                    state: cubit.state,
                    cubit: cubit,
                    canPublish: false,
                    device: PreviewDevice.phone,
                    pageId: 'home',
                    interactive: false,
                    onDeviceChanged: (v) => selectedDevice = v,
                    onPageChanged: (v) => selectedPage = v,
                    onModeChanged: (v) => selectedMode = v,
                    onReloadPreview: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        const ids = [
          'title',
          'device',
          'pages',
          'templates',
          'mode',
          'undo',
          'redo',
          'reload',
          'save',
          'history',
          'identity',
          'publish',
        ];
        final centers = [
          for (final id in ids)
            tester.getCenter(find.byKey(ValueKey('studio-tool-$id'))),
        ];
        for (var i = 1; i < centers.length; i++) {
          expect(centers[i].dy, closeTo(centers.first.dy, 0.1));
          expect(
            direction == TextDirection.rtl
                ? centers[i].dx < centers[i - 1].dx
                : centers[i].dx > centers[i - 1].dx,
            isTrue,
          );
        }
        expect(tester.getSize(find.byType(StudioSingleRowToolbar)).height, 60);
        expect(
          find.byKey(const ValueKey('studio-toolbar-row')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        if (width == 390) {
          expect(scroll.position.maxScrollExtent, greaterThan(0));
        }
        final publish = find.descendant(
          of: find.byKey(const ValueKey('studio-tool-publish')),
          matching: find.byType(TextButton),
        );
        expect(tester.widget<TextButton>(publish).onPressed, isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('studio-tool-device')),
        );
        await tester.tap(find.byKey(const ValueKey('studio-tool-device')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(PreviewDevice.phoneSmall.label).last);
        await tester.pumpAndSettle();
        expect(selectedDevice, PreviewDevice.phoneSmall);
        await tester.ensureVisible(
          find.byKey(const ValueKey('studio-tool-pages')),
        );
        await tester.tap(find.byKey(const ValueKey('studio-tool-pages')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PopupMenuItem<String> && w.value == 'categories',
          ),
        );
        await tester.pumpAndSettle();
        expect(selectedPage, 'categories');
        await tester.ensureVisible(
          find.byKey(const ValueKey('studio-tool-mode')),
        );
        await tester.tap(find.byKey(const ValueKey('studio-tool-mode')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PopupMenuItem<bool> && w.value == true,
          ),
        );
        await tester.pumpAndSettle();
        expect(selectedMode, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
