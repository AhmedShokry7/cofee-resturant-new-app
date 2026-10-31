import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/utils/localized_digits.dart';

/// الحقل الذي يرفض `٣٠٠` يخبر المدير أن رقمه غير صالح، فيعيد الكتابة بلغة
/// لا يكتب بها. هذه الدوال هي المصدر الوحيد الذي تسمّيه كل حقول الأرقام.
void main() {
  group('parseLocalizedNumber', () {
    test('يقرأ الأرقام العربية كما يقرأ اللاتينية', () {
      expect(parseLocalizedNumber('٣٠٠'), 300);
      expect(parseLocalizedNumber('300'), 300);
      expect(parseLocalizedNumber('١٢٫٥'), 12.5);
      expect(parseLocalizedNumber(' ٤٠ '), 40);
    });

    test('يرفض النص غير الرقمي بلا صفر مخترع', () {
      expect(parseLocalizedNumber(''), isNull);
      expect(parseLocalizedNumber('   '), isNull);
      expect(parseLocalizedNumber('ثلاثمئة'), isNull);
      expect(parseLocalizedNumber('٣٠٠ ريال'), isNull);
    });
  });

  group('parseLocalizedInt', () {
    test('يقرأ عددًا صحيحًا بأي أرقام', () {
      expect(parseLocalizedInt('٤'), 4);
      expect(parseLocalizedInt('4'), 4);
      expect(parseLocalizedInt(' ٠ '), 0);
    });

    test('يرجع null للفراغ وللعدد العشري وللنص', () {
      expect(parseLocalizedInt(''), isNull);
      expect(parseLocalizedInt('٢٫٥'), isNull);
      expect(parseLocalizedInt('five'), isNull);
    });
  });
}
