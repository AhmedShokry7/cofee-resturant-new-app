import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// سلامة سجل المكوّنات: مصدر حقيقة المحرّر.
///
/// ما يُسجّل هنا يحدد ما تراه لوحة الطبقات وما ترسله الشجرة للمعاينة،
/// فأي خلل فيه يظهر على الشاشة قبل أن يظهر في النشر.
void main() {
  setUpAll(ComponentRegistry.initialize);

  test('كل مكوّن مسجّل بلا تعارض', () {
    final all = ComponentRegistry.all;
    expect(all, isNotEmpty);
    final ids = all.map((e) => e.componentType).toSet();
    expect(ids, hasLength(all.length), reason: 'لا معرفات مكررة في السجل');
  });

  test('كل خاصية لها افتراضي في defaultValues أو قيمة nullable معلنة', () {
    for (final entry in ComponentRegistry.all) {
      entry.properties.forEach((key, definition) {
        final hasDefault = entry.defaultValues.containsKey(key);
        final nullable = definition.defaultValue == null;
        expect(
          hasDefault || nullable,
          isTrue,
          reason:
              'خاصية ${entry.componentType}.$key بلا افتراض ولا إعلان '
              'قيمة فارغة',
        );
      });
    }
  });

  test('كل مكوّن يسمح بإخفائه أو تحريره أو يُعلن محميًا', () {
    for (final entry in ComponentRegistry.all) {
      final invisible =
          entry.classification == ComponentClassification.static_;
      expect(
        invisible ||
            entry.allowedOperations.contains('hide') ||
            entry.allowedOperations.contains('reorder'),
        isTrue,
        reason:
            'مكوّن ${entry.componentType} بلا عمليات ولا يُعلن ثابتًا — '
            'لا معنى له في المحرر',
      );
    }
  });

  test('صفحات المحرر تدرك مكوّناتها المسموحة فقط', () {
    for (final page in EditorPages.pages) {
      for (final type in page.allowedComponentTypes) {
        expect(
          ComponentRegistry.get(type),
          isNotNull,
          reason: 'صفحة ${page.pageId} تسمح بمكوّن غير مسجّل: $type',
        );
      }
    }
  });

  test('الصفحات بمفاتيح العقد التي يقبلها المدقق الحي', () {
    const pageKeys = [
      'home',
      'categories',
      'search',
      'product_details',
      'cart',
      'favourites',
      'settings',
    ];
    expect(
      EditorPages.pages.map((p) => p.pageId),
      pageKeys,
      reason: 'مفتاح صفحة خارج قائمة app_design_is_valid يُرفض عند النشر',
    );
  });

  test('المكوّنات المحمية لا تُحذف', () {
    for (final entry in ComponentRegistry.all) {
      if (entry.classification == ComponentClassification.protected) {
        expect(
          entry.allowedOperations,
          isNot(contains('delete')),
          reason: 'مكوّن محمي ${entry.componentType} يسمح بحذفه',
        );
      }
    }
  });

  test('مقارنة الأب/الابن متسقة في الاتجاهين', () {
    // الجذر ليس مكوّنًا في السجل: الصفحات نفسها هي الحاويات الأولى.
    const pageKeys = {'home', 'categories', 'search', 'product_details',
      'cart', 'favourites', 'settings'};
    for (final entry in ComponentRegistry.all) {
      for (final parentType in entry.allowedParentTypes) {
        if (pageKeys.contains(parentType)) continue;
        final parent = ComponentRegistry.get(parentType);
        expect(
          parent,
          isNotNull,
          reason:
              '${entry.componentType} يسمح بأب غير مسجّل: $parentType',
        );
        expect(
          parent!.allowedChildTypes,
          contains(entry.componentType),
          reason:
              '${entry.componentType} يسمح بـ $parentType أبيض، لكن '
              '$parentType لا يسمح به ابناً — تعارض في الاتجاهين',
        );
      }
    }
  });
}
