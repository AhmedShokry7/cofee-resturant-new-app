import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class OnBoardingModel {
  final String image;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;

  OnBoardingModel({
    required this.image,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
  });

  String get title => pickText(
        (ar: titleAr ?? '', en: titleEn ?? ''),
        isArabic: AppLocale.instance.isArabic,
      );

  String get body => pickText(
        (ar: bodyAr ?? '', en: bodyEn ?? ''),
        isArabic: AppLocale.instance.isArabic,
      );

  factory OnBoardingModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return OnBoardingModel(
      image: Db.text(map['image_url']),
      titleAr: Db.textOrNull(map['title_ar']),
      titleEn: Db.textOrNull(map['title_en']),
      bodyAr: Db.textOrNull(map['body_ar']),
      bodyEn: Db.textOrNull(map['body_en']),
    );
  }
}
