import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory_extractor.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';

/// The menu the extractor is allowed to name — the canonical English names the
/// assistant files memories under, whichever language the customer speaks.
/// Anything outside it is not a preference about a product, and storing a whole
/// sentence about a word that is not on the menu is how a memory fills with
/// noise.
const _menu = ['Latte', 'Mocha', 'Cheesecake', 'Iced Latte'];

/// A catalogue with no English in it, which is what a shop that only filled
/// `name_ar` looks like.
const _arabicMenu = ['لاتيه', 'موكا'];

void main() {
  group('AssistantMemoryExtractor', () {
    test('a stated taste becomes a preference about the product named', () {
      final memories = AssistantMemoryExtractor.extract(
        'انا بحب اللاتيه البارد',
        products: _menu,
      );

      expect(memories, hasLength(1));
      expect(memories.first.kind, AssistantMemoryKind.preference);
      expect(memories.first.key, 'prefers:latte');
      expect(memories.first.isSecret, isFalse);
    });

    test('the dialect word and the menu word file the same memory', () {
      final arabic = AssistantMemoryExtractor.extract('انا بحب اللاتيه', products: _menu);
      final latin = AssistantMemoryExtractor.extract('i love latte', products: _menu);

      expect(arabic.single.key, latin.single.key);
    });

    test('a menu named only in Arabic is still understood', () {
      final memories = AssistantMemoryExtractor.extract(
        'بحب الموكا',
        products: _arabicMenu,
      );

      expect(memories.single.key, 'prefers:موكا');
    });

    test('the longer drink wins over the one inside its name', () {
      final memories = AssistantMemoryExtractor.extract(
        'بحب الايس لاتيه',
        products: _menu,
      );

      expect(memories, hasLength(1));
      expect(memories.single.key, 'prefers:iced latte');
    });

    test('a rejection is stored apart from a preference', () {
      final memories = AssistantMemoryExtractor.extract(
        'مش بحب الموكا',
        products: _menu,
      );

      expect(memories, hasLength(1));
      expect(memories.first.key, 'dislikes:mocha');
    });

    test('a judgement about the menu is an opinion, not a preference', () {
      final memories = AssistantMemoryExtractor.extract(
        'أفضل الموكا لأنه أحلى في الطعم',
        products: _menu,
      );

      expect(memories, isNotEmpty);
      expect(memories.first.kind, AssistantMemoryKind.opinion);
    });

    test('an allergy is a secret fact and outranks the rest of the sentence', () {
      final memories = AssistantMemoryExtractor.extract(
        'عندي حساسية من اللبن، بحب اللاتيه',
        products: _menu,
      );

      expect(memories, hasLength(1));
      expect(memories.first.kind, AssistantMemoryKind.fact);
      expect(memories.first.isSecret, isTrue);
      expect(memories.first.confidence, greaterThan(0.9));
    });

    test('a name is a fact with a fixed key so a rename supersedes it', () {
      final memories = AssistantMemoryExtractor.extract(
        'اسمي احمد',
        products: _menu,
      );

      expect(memories, hasLength(1));
      expect(memories.first.key, 'name:first');
      expect(memories.first.value, 'احمد');
    });

    test('a habit is weaker than a direct preference', () {
      final memories = AssistantMemoryExtractor.extract(
        'كل صباح بدي لاتيه',
        products: _menu,
      );

      expect(memories, hasLength(1));
      expect(memories.first.confidence, lessThan(0.8));
    });

    test('small talk stores nothing', () {
      for (final text in ['اه', 'تمام شكرا', 'hello there', 'من وينج؟']) {
        expect(
          AssistantMemoryExtractor.extract(text, products: _menu),
          isEmpty,
          reason: '"$text" is not a memory',
        );
      }
    });

    test('a sentence about nothing on the menu stores nothing', () {
      expect(
        AssistantMemoryExtractor.extract(
          'بحب الشاي بالنعناع',
          products: _menu,
        ),
        isEmpty,
      );
    });

    test('an assumption is labelled so the model asks instead of acting', () {
      final context = AssistantMemoryExtractor.toPromptContext([
        _item(AssistantMemoryKind.assumption, 'routine:general', 'always cold'),
        _item(AssistantMemoryKind.fact, 'name:first', 'Ahmed'),
      ]);

      expect(context, contains('[assumption]'));
      expect(context, contains('unconfirmed, ask rather than assume'));
      expect(context, contains('[fact] name:first: Ahmed'));
    });

    test('a private memory is shown as private, never as its sentence', () {
      final context = AssistantMemoryExtractor.toPromptContext([
        _item(AssistantMemoryKind.fact, 'health:allergy', '', isSecret: true),
      ]);

      expect(context, contains('health:allergy'));
      expect(context, contains('(kept private)'));
    });
  });
}

AssistantMemoryItem _item(
  AssistantMemoryKind kind,
  String key,
  String value, {
  bool isSecret = false,
}) {
  return AssistantMemoryItem(
    id: 'm-1',
    kind: kind,
    key: key,
    // A secret comes back from the server with no text at all; the client
    // never holds the sentence.
    value: isSecret ? '' : value,
    confidence: 0.8,
    source: AssistantMemorySource.userSaid,
    lastSeen: DateTime(2026, 11, 5),
  );
}
