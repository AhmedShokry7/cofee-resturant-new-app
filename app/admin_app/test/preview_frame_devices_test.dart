import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// انحدار قيود الإطار: كل أجهزة العرض تعمل حتى مع تكبير فوق الملاءمة،
/// وتمنع عودة خطأ القيود غير المُطبّعة (min>max) في OverflowBox.
void main() {
  testWidgets('كل الأجهزة تُبنى بلا انهيار قيود مع تكبير 1.3', (tester) async {
    for (final device in PreviewDevice.values) {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 700,
                height: 600,
                child: PreviewPanel(
                  pageId: 'home',
                  sessionId: 'test-session',
                  zoom: 1.3,
                  device: device,
                  components: const [],
                  theme: DesignTheme.none,
                  onElementSelected: (dynamic _) {},
                  onPreviewReady: (dynamic _) {},
                  onPreviewError: (dynamic _) {},
                  onPropertyUpdated: (dynamic _) {},
                  onTreeUpdated: (dynamic _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // لا استثناء قيود: لوحة المعاينة موجودة بجهازها.
      expect(find.byType(PreviewPanel), findsOneWidget,
          reason: 'جهاز ${device.label} يجب أن يُبنى بلا انهيار');
    }
  });
}
