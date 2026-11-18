import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// مكوّنات الشاشات المدمجة في المحرّر: صورة الترحيب وعنوانه ومسافاته،
/// شرائح التعريف ووقت انتقالها، وعناوين شاشات الدخول — كلها مسجّلة،
/// تُسمّى في العقد بمفاتيح الهاتف، وتبدأ من «تصميم اليوم» لا من فراغ.
void main() {
  setUpAll(() {
    ComponentRegistry.initialize();
    ComponentRegistry.all.forEach(DesignDocumentCodec.registerEntry);
  });

  test('مكوّنات الشاشات المدمجة مسجّلة كلها', () {
    const nativeTypes = [
      'splashSettings',
      'welcomeHero',
      'welcomeTitle',
      'welcomeBody',
      'welcomeSpacing',
      'welcomeCta',
      'onboardingSlide',
      'onboardingTransition',
      'authTitle',
      'authSubtitle',
      'authSocial',
      'authSwitchPrompt',
    ];
    for (final type in nativeTypes) {
      expect(
        ComponentRegistry.get(type),
        isNotNull,
        reason: 'مكوّن شاشة مدمجة $type غير مسجّل',
      );
    }
  });

  test('كل مكوّن مدمج مسموح في صفحته فقط', () {
    expect(
      EditorPages.findById('splash')!.allowedComponentTypes,
      contains('splashSettings'),
    );
    expect(
      EditorPages.findById('welcome')!.allowedComponentTypes,
      containsAll([
        'welcomeHero',
        'welcomeTitle',
        'welcomeBody',
        'welcomeSpacing',
        'welcomeCta',
      ]),
    );
    expect(
      EditorPages.findById('onboarding')!.allowedComponentTypes,
      containsAll(['onboardingSlide', 'onboardingTransition']),
    );
    expect(
      EditorPages.findById('auth')!.allowedComponentTypes,
      containsAll([
        'authTitle',
        'authSubtitle',
        'authSocial',
        'authSwitchPrompt',
      ]),
    );
    expect(
      EditorPages.findById('settings')!.allowedComponentTypes,
      isNot(contains('authTitle')),
      reason: 'مكوّن شاشة دخول لا ينتمي إلى شاشة الإعدادات',
    );
  });

  test('مفاتيح الشاشات المدمجة في العقد هي التي يفهمها الهاتف', () {
    for (final internal in const [
      'splashSettings',
      'welcomeHero',
      'welcomeTitle',
      'welcomeBody',
      'welcomeSpacing',
      'welcomeCta',
      'onboardingSlide',
      'onboardingTransition',
      'authTitle',
      'authSubtitle',
      'authSocial',
      'authSwitchPrompt',
    ]) {
      final contract = DesignDocumentCodec.phoneTypes[internal];
      expect(contract, isNotNull, reason: '$internal بلا مفتاح عقد');
      expect(
        DesignContract.sectionTypes,
        contains(contract),
        reason: '$contract غائب عن عقد اللوحة — الهاتف يرسمه والنشر يرفضه',
      );
    }
  });

  test('صفحات الشاشات المدمجة تبدأ من عقد أصلها بخصائص فارغة', () {
    for (final pageId in const [
      'splash',
      'welcome',
      'onboarding',
      'auth',
      'sign_up',
      'forget_password',
      'reset_password',
      'phone_auth',
      'email_auth',
    ]) {
      final components = DesignDocumentCodec.defaultComponentsFor(pageId);
      expect(
        components,
        isNotEmpty,
        reason: 'صفحة $pageId تبدأ من شجرة فارغة لا من عقد أصلها',
      );
      for (final component in components) {
        expect(component.pageId, pageId);
        // خاصية فارغة تُنشر تعني «كما هو» — نشر اليوم دون تعديل لا يغيّر
        // شاشة الزبون حرفًا.
        if (component.componentType != 'splashSettings') {
          expect(
            component.properties['imageUrl'] ?? '',
            isEmpty,
            reason: 'عقدة أصل في $pageId تبدأ بقيمة مختلقة',
          );
        }
        if (component.componentType == 'splashSettings') {
          expect(component.properties['durationMs'], 1000);
          expect(component.properties['backgroundColor'], '#FFFFFF');
        }
      }
    }
  });

  test('مستند الصفحات المدمجة يمرّ من التحقق الحيّ ويقرأ مجددًا', () {
    final componentsByPage = {
      for (final page in EditorPages.pages)
        page.pageId: DesignDocumentCodec.defaultComponentsFor(page.pageId),
    };
    final document = DesignDocumentCodec.document(componentsByPage);

    expect(
      DesignDocumentCodec.validate(document),
      isNull,
      reason: 'تصميم اليوم لا يُنشر إلا كما هو',
    );

    final welcome = document['pages']!.firstWhere(
      (page) => page['page'] == 'welcome',
    ) as Map;
    final types = [
      for (final child in welcome['root']['children'] as List)
        child['type'] as String,
    ];
    expect(
      types,
      containsAll([
        DesignContract.welcomeHero,
        DesignContract.welcomeTitle,
        DesignContract.welcomeBody,
        DesignContract.welcomeSpacing,
      ]),
    );
  });

  test('عقدة شريحة تعريف تعود من المستند كما كُتبت', () {
    final componentsByPage = {
      'onboarding': DesignDocumentCodec.defaultComponentsFor('onboarding'),
    };
    final document = DesignDocumentCodec.document(componentsByPage);
    final parsed = DesignDocumentCodec.parsePage(
      'onboarding',
      (document['pages']!.first as Map)['root']['children'],
    );

    expect(parsed, hasLength(4));
    expect(
      parsed.map((c) => c.componentType),
      containsAll(['onboardingSlide', 'onboardingTransition']),
    );
  });
}
