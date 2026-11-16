import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';

/// شرائح التعريف كما يقولها المستند المنشور.
///
/// كل عقدة `onboarding.slide` في صفحة `onboarding` شريحة، بترتيبها
/// المنشور: صورة (`imageUrl`) وعنوان (`title`) ووصف (`body`)، وكل خاصية
/// فارغة أو غائبة تسقط على شريحة المصدر بالمكان نفسه — فالشريحة ناقصة
/// النص لا تصبح شريحة فارغة. لا شرائح في المستند يعني شرائح المصدر.
/// العقدة المخفية تسقط من الترتيب لا تُرسم فراغًا.
List<OnBoardingModel> onboardingSlidesFrom(
  List<PublishedSection> sections,
) {
  final slideNodes = sections
      .where(
        (section) =>
            section.visible && section.type == DesignWidgetTypes.onboardingSlide,
      )
      .toList();
  if (slideNodes.isEmpty) return onBoardingSlides();
  final fallback = onBoardingSlides();
  String _value(String? published, String source) {
    final text = published?.trim() ?? '';
    return text.isEmpty ? source : text;
  }

  return [
    for (var index = 0; index < slideNodes.length; index++)
      OnBoardingModel(
        image: _value(
          slideNodes[index].property('imageUrl'),
          fallback[index % fallback.length].image,
        ),
        title: _value(
          slideNodes[index].localizedText('title'),
          fallback[index % fallback.length].title,
        ),
        body: _value(
          slideNodes[index].localizedText('body'),
          fallback[index % fallback.length].body,
        ),
      ),
  ];
}

/// إعداد الانتقال كما يقوله المستند: مدة الحركة بالمللي ثانية
/// (`durationMs`)، ووقت التقديم التلقائي بالثواني (`seconds` — صفر أو
/// غياب يعني لا تقديم تلقائي). القيم التالفة أو الغائبة تعني أصل الحركة.
({Duration? autoAdvance, Duration? slideDuration}) onboardingTransitionFrom(
  List<PublishedSection> sections,
) {
  final node = nativeSection(
    sections,
    DesignWidgetTypes.onboardingTransition,
  );
  final ms = node?.numberProperty('durationMs');
  final slideDuration = ms != null && ms >= 150
      ? Duration(milliseconds: ms.round())
      : null;
  final seconds = node?.numberProperty('seconds') ?? 0;
  final autoAdvance = seconds >= 1
      ? Duration(seconds: seconds.round())
      : null;
  return (autoAdvance: autoAdvance, slideDuration: slideDuration);
}
