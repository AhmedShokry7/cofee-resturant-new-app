import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class OnBoardingModel {
  const OnBoardingModel({
    required this.title,
    required this.body,
    required this.image,
  });

  final String title;
  final String body;
  final String image;

  /// Reads one `core.onboarding_slides` row. Text resolves in the app language,
  /// falling back to the other language rather than rendering blank.
  factory OnBoardingModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return OnBoardingModel(
      title: pickText((
        ar: Db.textOrNull(map['title_ar']) ?? '',
        en: Db.textOrNull(map['title_en']) ?? '',
      ), isArabic: AppLocale.instance.isArabic),
      body: pickText((
        ar: Db.textOrNull(map['body_ar']) ?? '',
        en: Db.textOrNull(map['body_en']) ?? '',
      ), isArabic: AppLocale.instance.isArabic),
      image: Db.textOrNull(map['image_url']) ?? '',
    );
  }
}
