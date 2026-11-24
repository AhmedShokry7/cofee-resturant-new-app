import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/auth/presentation/models/invitation_link.dart';

void main() {
  const token = '3f6a2b1e-8c4d-4e5f-9a0b-1c2d3e4f5a6b';

  group('InvitationLink', () {
    test('extracts an encoded invite and ignores unrelated auth params', () {
      final uri = Uri.parse(
        'https://example.test/admin/?mode=staff&invite=$token&token_hash=otp',
      );

      expect(InvitationLink.tokenFromUri(uri), token);
      expect(InvitationLink.containsInviteParameter(uri), isTrue);
    });

    test('reads a fragment query but ignores OTP-only links', () {
      expect(
        InvitationLink.tokenFromUri(
          Uri.parse('https://example.test/admin/#/invite=$token&lang=ar'),
        ),
        token,
      );
      expect(
        InvitationLink.tokenFromUri(
          Uri.parse('https://example.test/admin/#access_token=secret'),
        ),
        isNull,
      );
    });

    test(
      'rejects missing, empty, duplicate and malformed invitation values',
      () {
        for (final url in <String>[
          'https://example.test/admin/?token=$token',
          'https://example.test/admin/?invite=',
          'https://example.test/admin/?invite=$token&invite=$token',
          'https://example.test/admin/?invite=not-a-uuid',
        ]) {
          final uri = Uri.parse(url);
          expect(InvitationLink.tokenFromUri(uri), isNull, reason: url);
        }

        expect(
          InvitationLink.containsInviteParameter(
            Uri.parse('https://example.test/admin/?invite='),
          ),
          isTrue,
        );
      },
    );

    test(
      'builds the configured acceptance link preserving other parameters',
      () {
        final current = Uri.parse(
          'https://example.test/admin/?lang=ar&campaign=staff&invite=old',
        );
        final result = InvitationLink.acceptanceUri(current, token)!;

        expect(result.origin, current.origin);
        expect(result.path, '/admin/');
        expect(result.queryParameters['lang'], 'ar');
        expect(result.queryParameters['campaign'], 'staff');
        expect(result.queryParameters['invite'], token);
        expect(result.queryParameters.containsKey('token'), isFalse);
      },
    );

    test('uses an explicit secure app URL when there is no web origin', () {
      final result = InvitationLink.acceptanceUri(
        Uri.parse('about:blank'),
        token,
        applicationUrl: 'https://admin.example.test/admin/',
      );

      expect(result?.origin, 'https://admin.example.test');
      expect(result?.path, '/admin/');
      expect(result?.queryParameters['invite'], token);
    });

    test('refuses malformed or insecure configured app URLs', () {
      for (final value in <String>[
        'http://admin.example.test/',
        'https://admin.example.test/?invite=other',
        'https://user:pass@admin.example.test/',
        'not-a-url',
      ]) {
        expect(
          InvitationLink.acceptanceUri(
            Uri.parse('about:blank'),
            token,
            applicationUrl: value,
          ),
          isNull,
          reason: value,
        );
      }
    });
  });
}
