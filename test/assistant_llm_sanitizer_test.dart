// The chat bubble is a plain text widget.
//
// The model writes for documents: tables, bullet lists, headings, bold and
// emoji. All of that has to go before the customer reads it, because a table
// in a chat bubble is a wall of pipes.
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/assistant/data/llm/llm_reply_sanitizer.dart';

void main() {
  test('a markdown table becomes plain lines', () {
    const table = '''
| الميزة | اللاتيه | الكابتشينو |
|--------|-------|-----------|
| المكون | حليب | رغوة |
''';

    final result = sanitizeLlmReply(table);

    expect(result, isNot(contains('|')));
    expect(result, contains('المكون'));
    expect(result, contains('حليب'));
    expect(result, contains('رغوة'));
  });

  test('the table header names the value', () {
    const table = '''
| الميزة | اللاتيه |
|--------|---------|
| المكون | حليب |
''';

    final result = sanitizeLlmReply(table);

    expect(result, contains('اللاتيه: حليب'));
  });

  test('a bullet list becomes readable dots', () {
    final result = sanitizeLlmReply('- كابتشينو\n- لاتيه');

    expect(result, '• كابتشينو\n• لاتيه');
  });

  test('a numbered list keeps its number', () {
    final result = sanitizeLlmReply('1. كابتشينو\n2. لاتيه');

    expect(result, '1) كابتشينو\n2) لاتيه');
  });

  test('headings lose their hashes', () {
    expect(sanitizeLlmReply('## الأسعار'), 'الأسعار');
    expect(sanitizeLlmReply('### الأسعار'), 'الأسعار');
  });

  test('bold and italic markers go', () {
    expect(sanitizeLlmReply('**سعر** اللاتيه'), 'سعر اللاتيه');
    expect(sanitizeLlmReply('*سعر* اللاتيه'), 'سعر اللاتيه');
  });

  test('the emoji go', () {
    expect(sanitizeLlmReply('أحلى مشروب ☕ عندنا'), 'أحلى مشروب عندنا');
  });

  test('a horizontal rule goes', () {
    expect(sanitizeLlmReply('السعر\n---\nالتوصيل'), 'السعر\n\nالتوصيل');
  });

  test('a plain sentence is untouched', () {
    const sentence = 'سعر اللاتيه 35.00 SAR. تحبه ساخن ولا بارد؟';

    expect(sanitizeLlmReply(sentence), sentence);
  });

  test('an empty reply stays empty', () {
    expect(sanitizeLlmReply('   '), '');
  });
}
