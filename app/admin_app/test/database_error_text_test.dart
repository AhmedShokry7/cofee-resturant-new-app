import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/utils/database_error_text.dart';

void main() {
  test('يعرض نصّ القاعدة حين تشرح سبب الرفض', () {
    final error = PostgrestException(
      message: 'transition ready -> pending is not allowed',
      code: '23514',
    );
    expect(
      databaseErrorText(error, fallback: 'failed'),
      'transition ready -> pending is not allowed',
    );
  });

  test('يرجع للرسالة العامة حين لا يوجد نص مفيد', () {
    expect(
      databaseErrorText(
        PostgrestException(message: '   ', code: '42501'),
        fallback: 'failed',
      ),
      'failed',
    );
    expect(databaseErrorText(StateError('down'), fallback: 'failed'), 'failed');
  });
}
