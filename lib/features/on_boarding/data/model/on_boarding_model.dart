import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class OnBoardingModel {
  final String image;
  final String title;
  final String body;

  OnBoardingModel({
    required this.image,
    required this.title,
    required this.body,
  });

  factory OnBoardingModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    final isArabic = AppLocale.instance.isArabic;
    final titleAr = Db.textOrNull(map['title_ar']) ?? '';
    final titleEn = Db.textOrNull(map['title_en']) ?? '';
    final bodyAr = Db.textOrNull(map['body_ar']) ?? '';
    final bodyEn = Db.textOrNull(map['body_en']) ?? '';
    return OnBoardingModel(
      image: Db.textOrNull(map['image_url']) ?? '',
      title: isArabic
          ? (titleAr.isNotEmpty ? titleAr : titleEn)
          : (titleEn.isNotEmpty ? titleEn : titleAr),
      body: isArabic
          ? (bodyAr.isNotEmpty ? bodyAr : bodyEn)
          : (bodyEn.isNotEmpty ? bodyEn : bodyAr),
    );
  }
}
