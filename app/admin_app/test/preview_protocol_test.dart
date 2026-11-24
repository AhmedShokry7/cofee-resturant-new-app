import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPreviewMessageAllowed — التحقق من المصدر والجلسة', () {
    const previewOrigin = 'http://localhost:5000';
    const adminOrigin = 'http://127.0.0.1:8080';
    final message = {'sessionId': 've_1', 'type': 'PREVIEW_READY'};

    test('1 — origin تطبيق العميل الصحيح مع جلسة صحيحة يُقبل', () {
      expect(
        isPreviewMessageAllowed(
          senderOrigin: previewOrigin,
          expectedOrigin: previewOrigin,
          data: message,
          expectedSessionId: 've_1',
        ),
        isTrue,
      );
    });

    test('2 — origin غير مصرح به (الأدمن نفسه أو مصدر غريب) يُرفض', () {
      expect(
        isPreviewMessageAllowed(
          senderOrigin: adminOrigin,
          expectedOrigin: previewOrigin,
          data: message,
          expectedSessionId: 've_1',
        ),
        isFalse,
        reason: 'المصدر يجب أن يكون الإطار لا الأدمن',
      );
      expect(
        isPreviewMessageAllowed(
          senderOrigin: 'https://evil.example',
          expectedOrigin: previewOrigin,
          data: message,
          expectedSessionId: 've_1',
        ),
        isFalse,
      );
    });

    test('3 — sessionId غير صحيح يُرفض، والبيانات غير خريطة تُرفض', () {
      expect(
        isPreviewMessageAllowed(
          senderOrigin: previewOrigin,
          expectedOrigin: previewOrigin,
          data: {'sessionId': 've_999'},
          expectedSessionId: 've_1',
        ),
        isFalse,
      );
      expect(
        isPreviewMessageAllowed(
          senderOrigin: previewOrigin,
          expectedOrigin: previewOrigin,
          data: 'not-a-map',
          expectedSessionId: 've_1',
        ),
        isFalse,
      );
    });

    test('origin مفقود في الإعداد أو في الرسالة يرفض كل شيء', () {
      expect(
        isPreviewMessageAllowed(
          senderOrigin: previewOrigin,
          expectedOrigin: null,
          data: message,
          expectedSessionId: 've_1',
        ),
        isFalse,
      );
      expect(
        isPreviewMessageAllowed(
          senderOrigin: null,
          expectedOrigin: previewOrigin,
          data: message,
          expectedSessionId: 've_1',
        ),
        isFalse,
      );
    });
  });

  group('PreviewOutboundQueue — الطابور قبل الجاهزية', () {
    test('4 — الرسائل قبل PREVIEW_READY تحفظ في الطابور ولا تُرسل', () {
      final queue = PreviewOutboundQueue<String>();
      expect(queue.offer('msg-1'), isFalse, reason: 'القناة ليست جاهزة');
      expect(queue.offer('msg-2'), isFalse);
      expect(queue.isReady, isFalse);
      expect(queue.length, 2);
    });

    test('5 — الرسائل المعلقة تُصرف بالترتيب بعد الجاهزية', () {
      final queue = PreviewOutboundQueue<String>();
      queue
        ..offer('msg-1')
        ..offer('msg-2')
        ..offer('msg-3');
      expect(queue.markReady(), isTrue);
      expect(queue.drain(), ['msg-1', 'msg-2', 'msg-3']);
      // بعد الصرف: الرسائل الجديدة تمر مباشرة.
      expect(queue.offer('msg-4'), isTrue);
      expect(queue.drain(), isEmpty);
    });

    test('قناة جاهزة من البداية تمرر فورًا بلا طابور', () {
      final queue = PreviewOutboundQueue<String>()..markReady();
      expect(queue.offer('direct'), isTrue);
    });

    test('6 — إعادة التحميل تحفظ الرسائل المعلقة وتسقط الجاهزية فقط', () {
      // الطابور يحفظ التعديلات وهم لم تصير القناة جاهزة بعد (إطار يُحمّل).
      final queue = PreviewOutboundQueue<String>()
        ..offer('latest-document')
        ..reset(keepPending: true);
      expect(queue.isReady, isFalse);
      expect(queue.length, 1, reason: 'آخر مستند لا يضيع مع إعادة التحميل');
      queue.markReady();
      expect(queue.drain().single, 'latest-document');
    });
  });

  group('decodePreviewPayload — فكّ الحمولة الواردة', () {
    const body =
        '{"protocolVersion":"1.0","sessionId":"ve_1","type":"APPLY_DESIGN_CONFIG","payload":{"x":1}}';

    test('نص JSON صالح يُفكّ إلى خريطة', () {
      final decoded = decodePreviewPayload(body);
      expect(decoded, isNotNull);
      expect(decoded!['sessionId'], 've_1');
      expect(decoded['type'], 'APPLY_DESIGN_CONFIG');
    });

    test('خريطة جاهزة تمر كما هي، ونص تالف وغيرهما تعود null', () {
      expect(decodePreviewPayload({'sessionId': 've_1'}), isNotNull);
      expect(decodePreviewPayload('{broken json'), isNull);
      expect(decodePreviewPayload(42), isNull);
      expect(decodePreviewPayload(null), isNull);
    });
  });

  group('previewOriginOf', () {
    test('يستخرج origin تطبيق العميل من رابط المعاينة كاملًا', () {
      expect(
        previewOriginOf(
          'http://localhost:5000/?mode=preview&sessionId=ve_1&parentOrigin=x',
        ),
        'http://localhost:5000',
      );
      expect(
        previewOriginOf('http://127.0.0.1:5000/'),
        'http://127.0.0.1:5000',
      );
      expect(previewOriginOf(null), isNull);
      expect(previewOriginOf('not-a-url:://'), isNull);
    });

    test('المنفذ جزء من الهوية — localhost و127.0.0.1 مصدران مختلفان', () {
      expect(
        previewOriginOf('http://localhost:5000') ==
            previewOriginOf('http://127.0.0.1:5000'),
        isFalse,
      );
    });
  });
}
