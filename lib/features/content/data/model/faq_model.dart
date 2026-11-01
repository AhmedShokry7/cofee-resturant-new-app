import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class FaqModel {
  const FaqModel({
    String? question,
    String? answer,
    this.questionAr,
    this.questionEn,
    this.answerAr,
    this.answerEn,
  }) : _legacyQuestion = question ?? '',
       _legacyAnswer = answer ?? '';

  final String? questionAr;
  final String? questionEn;
  final String? answerAr;
  final String? answerEn;

  final String _legacyQuestion;
  final String _legacyAnswer;

  String get question {
    final text = pickText((
      ar: questionAr ?? '',
      en: questionEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyQuestion : text;
  }

  String get answer {
    final text = pickText((
      ar: answerAr ?? '',
      en: answerEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyAnswer : text;
  }

  factory FaqModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return FaqModel(
      questionAr: Db.textOrNull(map['question_ar']),
      questionEn: Db.textOrNull(map['question_en']),
      answerAr: Db.textOrNull(map['answer_ar']),
      answerEn: Db.textOrNull(map['answer_en']),
    );
  }
}
