import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';
import 'package:new_coffee/features/content/data/model/legal_document_model.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/content/presentation/views/help_page.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/content_failure_view.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/faq_card.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// A backend that answers with whatever the test needs, and counts the reads so
/// a retry can be told apart from an automatic second query.
class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository({this.publishedFaqs = const [], this.failure});

  final List<FaqModel> publishedFaqs;
  final String? failure;

  int faqsCalls = 0;

  @override
  Future<List<FaqModel>> faqs() async {
    faqsCalls++;
    if (failure != null) throw StateError(failure!);
    return publishedFaqs;
  }

  @override
  Future<LegalDocumentModel?> legalDocument(String slug) async => null;
}

Future<void> _pumpHelp(
  WidgetTester tester,
  ContentRepository repository,
) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      // The app's own design size, read from the token rather than restated.
      designSize: AppConstant.designSize,
      builder: (context, _) => RepositoryProvider<ContentRepository>.value(
        value: repository,
        child: const MaterialApp(home: HelpPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('help centre', () {
    testWidgets('lists every published question under the section heading', (
      tester,
    ) async {
      await _pumpHelp(
        tester,
        _FakeContentRepository(
          publishedFaqs: const [
            FaqModel(question: 'Where is my order?', answer: 'On the way.'),
            FaqModel(question: 'How do I pay?', answer: 'Card or cash.'),
          ],
        ),
      );

      expect(find.text(S.faqTitle), findsOneWidget);
      expect(find.byType(FaqCard), findsNWidgets(2));
      expect(find.text('Where is my order?'), findsOneWidget);
    });

    testWidgets('an answer stays folded until the customer opens it', (
      tester,
    ) async {
      await _pumpHelp(
        tester,
        _FakeContentRepository(
          publishedFaqs: const [
            FaqModel(question: 'Where is my order?', answer: 'On the way.'),
          ],
        ),
      );

      expect(find.text('On the way.'), findsNothing);

      await tester.tap(find.text('Where is my order?'));
      await tester.pumpAndSettle();

      expect(find.text('On the way.'), findsOneWidget);
    });

    testWidgets('a failed read says so in the customer\'s words and retries', (
      tester,
    ) async {
      final repository = _FakeContentRepository(
        failure: 'PostgrestException: relation "faq_items" does not exist',
      );
      await _pumpHelp(tester, repository);

      expect(find.byType(ContentFailureView), findsOneWidget);
      expect(find.text(S.couldNotLoadFaqs), findsOneWidget);
      // The raw backend message must not reach the screen.
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(repository.faqsCalls, 1);

      await tester.tap(find.text(S.retry));
      await tester.pumpAndSettle();

      expect(repository.faqsCalls, 2);
    });

    testWidgets('no published questions is stated, not left blank', (
      tester,
    ) async {
      await _pumpHelp(tester, _FakeContentRepository());

      expect(find.text(S.noFaqs), findsOneWidget);
      expect(find.byType(FaqCard), findsNothing);
    });

    testWidgets('the loading skeleton is replaced by the list, not stacked', (
      tester,
    ) async {
      final repository = _FakeContentRepository(
        publishedFaqs: const [FaqModel(question: 'Q', answer: 'A')],
      );
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: AppConstant.designSize,
          builder: (context, _) => RepositoryProvider<ContentRepository>.value(
            value: repository,
            child: const MaterialApp(home: HelpPage()),
          ),
        ),
      );

      // Before the read settles the skeleton is what the customer sees.
      expect(find.byType(FaqLoadingView), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(FaqLoadingView), findsNothing);
      expect(find.byType(FaqCard), findsOneWidget);
    });
  });
}
