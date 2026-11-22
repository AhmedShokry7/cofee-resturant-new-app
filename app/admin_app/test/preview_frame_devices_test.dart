import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/native_design_preview.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// انحدار قيود الإطار: كل أجهزة العرض تعمل حتى مع تكبير فوق الملاءمة،
/// وتمنع عودة خطأ القيود غير المُطبّعة (min>max) في OverflowBox.
///
/// ويؤكد قاعدتي المحاكي:
/// - الإطار مثبّت في منتصف مسرحه مهما تغيّر الجهاز — لا انحياز لليسار
///   ولا لليمين ولا قفزات عند التبديل.
/// - كل جهاز يُرسم بحجمه الفعلي فتظهر درجات الحجم للعميل.
void main() {
  testWidgets('الإطار مثبت في المنتصف ويغير حجمه مع كل جهاز', (tester) async {
    Future<Rect> frameBounds(PreviewDevice device) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 700,
                  height: 600,
                  child: PreviewPanel(
                    pageId: 'home',
                    sessionId: 'test-session',
                    zoom: 1,
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
        ),
      );
      await tester.pump();
      await tester.pump();
      // جسم المحاكي: الحاوية الملونة بلون كروم الجهاز.
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(NativeDesignPreview),
          matching: find.byType(Container),
        ).first,
      );
      return tester.getRect(find.byWidget(container));
    }

    final phone = await frameBounds(PreviewDevice.phoneSmall);
    // المنتصف مطابق لمنتصف المسرح (700×600) رأسيًا وأفقيًا.
    expect(phone.center.dx, closeTo(600, 1));
    expect(phone.center.dy, closeTo(400, 1));

    final tablet = await frameBounds(PreviewDevice.tabletLandscape);
    expect(tablet.center.dx, closeTo(600, 1), reason: 'يبقى مثبتًا بالمنتصف');
    expect(tablet.center.dy, closeTo(400, 1), reason: 'يبقى مثبتًا بالمنتصف');
    // الجهاز الأكبر أعرض فعليًا فتُقرأ درجات الحجم.
    expect(tablet.width, greaterThan(phone.width));
  });

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
