import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';
import 'package:new_coffee/features/content/data/model/legal_document_model.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/content/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/content_failure_view.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// A backend that serves one published document, records the slug it was asked
/// for, and counts the reads so a retry is distinguishable.
class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository({this.document, this.failure});

  final LegalDocumentModel? document;
  final String? failure;

  int calls = 0;
  String? askedSlug;

  @override
  Future<LegalDocumentModel?> legalDocument(String slug) async {
    calls++;
    askedSlug = slug;
    if (failure != null) throw StateError(failure!);
    return document;
  }

  @override
  Future<List<FaqModel>> faqs() async => const [];
}

Future<void> _pumpPolicy(
  WidgetTester tester,
  ContentRepository repository,
) async {
  await tester.pumpWidget(
    RepositoryProvider<ContentRepository>.value(
      value: repository,
      child: const MaterialApp(home: PrivacyPolicyPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('published legal document', () {
    testWidgets('asks for the document the page is named for', (tester) async {
      final repository = _FakeContentRepository(
        document: const LegalDocumentModel(
          id: 'doc-1',
          slug: 'privacy',
          content: 'We keep your data.',
        ),
      );
      await _pumpPolicy(tester, repository);

      expect(repository.askedSlug, PrivacyPolicyPage.documentSlug);
      expect(find.text('We keep your data.'), findsOneWidget);
    });

    testWidgets('a read that finds nothing says the text is unavailable', (
      tester,
    ) async {
      await _pumpPolicy(tester, _FakeContentRepository());

      expect(find.text(S.policyUnavailable), findsOneWidget);
    });

    testWidgets('a failed read offers the retry, not the backend message', (
      tester,
    ) async {
      final repository = _FakeContentRepository(
        failure: 'PostgrestException: could not connect',
      );
      await _pumpPolicy(tester, repository);

      expect(find.byType(ContentFailureView), findsOneWidget);
      expect(find.text(S.couldNotLoadPolicy), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);

      await tester.tap(find.text(S.retry));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
    });

    testWidgets('the skeleton gives the page over once the text arrives', (
      tester,
    ) async {
      final repository = _FakeContentRepository(
        document: const LegalDocumentModel(
          id: 'doc-1',
          slug: 'privacy',
          content: 'We keep your data.',
        ),
      );
      await tester.pumpWidget(
        RepositoryProvider<ContentRepository>.value(
          value: repository,
          child: const MaterialApp(home: PrivacyPolicyPage()),
        ),
      );

      expect(find.byType(PolicyLoadingView), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(PolicyLoadingView), findsNothing);
      expect(find.text('We keep your data.'), findsOneWidget);
    });
  });
}
