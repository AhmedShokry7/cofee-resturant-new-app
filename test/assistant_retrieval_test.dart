// The retrieval contract, on its own.
//
// Retrieval is the piece that decides what the model is allowed to state about
// the shop, and what the customer is shown as proof. Both halves are tested
// here: the rows the database gives back and the citation the app renders from
// them.
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';

const _article = RetrievedSource(
  sourceType: 'article',
  sourceId: 'faq-hours',
  title: 'مواعيد العمل',
  body: 'من السابعة صباحاً حتى الحادية عشرة مساءً',
  score: 0.8,
);

const _product = RetrievedSource(
  sourceType: 'product',
  sourceId: 'p-7',
  title: 'موكا',
  body: 'إسبريسو وشوكولاتة ولبن',
  score: 0.6,
);

const _webPage = RetrievedSource(
  sourceType: 'web',
  sourceId: 'https://news.test/story',
  title: 'A story',
  body: '',
  score: 1,
  uri: 'https://news.test/story',
);

void main() {
  group('a retrieved row', () {
    test('is read from the shape the function returns', () {
      final source = RetrievedSource.fromRow({
        'source_type': 'article',
        'source_id': 'shipping',
        'title': 'الشحن',
        'body': 'خلال ساعة',
        'score': 0.42,
        'uri': 'https://shop.test/shipping',
      });

      expect(source, isNotNull);
      expect(source!.sourceId, 'shipping');
      expect(source.score, 0.42);
      expect(source.uri, 'https://shop.test/shipping');
    });

    test('without an identity is dropped, not cited as nothing', () {
      expect(
        RetrievedSource.fromRow({'source_type': 'article', 'title': 'بلا عنوان'}),
        isNull,
      );
    });

    test('a shop row is not a link, a web row is', () {
      expect(_article.isLink, isFalse);
      expect(_webPage.isLink, isTrue);
    });

    test('a link without a scheme is not offered as tappable', () {
      for (final uri in [
        'javascript:alert(1)',
        'file:///C:/secrets',
        'https://',
        '',
      ]) {
        expect(
          _webPage.copyWith(uri: uri).isLink,
          isFalse,
          reason: '"$uri" is not a page the customer should be sent to',
        );
      }
    });
  });

  group('the sources under an answer', () {
    test('the same page reached with different parameters is named once', () {
      const once = RetrievedSource(
        sourceType: 'web',
        sourceId: 'https://news.test/story',
        title: 'A story',
        body: '',
        score: 1,
        uri: 'https://news.test/story',
      );
      const samePageAgain = RetrievedSource(
        sourceType: 'web',
        sourceId: 'https://news.test/story?utm_source=assistant',
        title: 'A story, again',
        body: '',
        score: 1,
        uri: 'https://news.test/story?utm_source=assistant',
      );

      expect(dedupeSources(const [once, samePageAgain]), [once]);
    });

    test('the order they were read in is kept', () {
      expect(
        dedupeSources(const [_article, _product, _webPage]).map((s) => s.sourceId),
        ['faq-hours', 'p-7', 'https://news.test/story'],
      );
    });

    test('rows without a link are told apart by their own identity', () {
      final first = _article.copyWith(sourceId: 'a');
      final second = _article.copyWith(sourceId: 'b');

      expect(dedupeSources([first, second]), hasLength(2));
    });
  });

  group('the prompt built from them', () {
    test('names each document by the id the customer can be shown', () {
      final prompt = buildRetrievedContext(const [_article, _product]);

      expect(prompt, contains('[faq-hours] مواعيد العمل'));
      expect(prompt, contains('[p-7] موكا'));
    });

    test('closes with the rule that makes retrieval mean something', () {
      final prompt = buildRetrievedContext(const [_article]);

      expect(prompt, contains('say you do not know instead of guessing'));
    });

    test('a long article is cut instead of spending the whole turn', () {
      final prompt = buildRetrievedContext(
        [
          RetrievedSource(
            sourceType: 'article',
            sourceId: 'long',
            title: 'حكاية طويلة',
            body: 'ك' * 900,
            score: 0.9,
          ),
        ],
        maxChars: 40,
      );

      expect(prompt, contains('ك' * 40));
      expect(prompt, isNot(contains('ك' * 41)));
    });

    test('nothing retrieved builds no prompt', () {
      expect(buildRetrievedContext(const []), isEmpty);
    });
  });
}
