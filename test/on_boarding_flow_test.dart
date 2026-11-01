import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';

/// The onboarding used to render copy written inside the feature and to
/// navigate from its cubit. These tests lock the shape it has now: the copy
/// comes from `S`, and the cubit only reports that the onboarding is done.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('slides', () {
    test('are the three intro slides, labelled from S', () {
      final slides = onBoardingSlides();

      expect(slides, hasLength(3));
      expect(
        slides.map((slide) => slide.title),
        [
          S.onBoardingCatalogTitle,
          S.onBoardingPaymentTitle,
          S.onBoardingAssistantTitle,
        ],
      );
      expect(
        slides.map((slide) => slide.body),
        [
          S.onBoardingCatalogBody,
          S.onBoardingPaymentBody,
          S.onBoardingAssistantBody,
        ],
      );
    });

    test('every slide carries an image and no empty label', () {
      for (final slide in onBoardingSlides()) {
        expect(slide.image, isNotEmpty);
        expect(slide.title, isNotEmpty);
        expect(slide.body, isNotEmpty);
      }
    });
  });

  group('cubit', () {
    test('the last slide completes the onboarding instead of navigating', () async {
      final cubit = OnBoardingCubit();
      addTearDown(cubit.close);
      cubit.currentPage = onBoardingSlides().length - 1;

      await cubit.next();

      expect(cubit.state, isA<OnBoardingCompleted>());
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });

    test('skipping records the same marker the last slide does', () async {
      final cubit = OnBoardingCubit();
      addTearDown(cubit.close);

      await cubit.complete();

      expect(cubit.state, isA<OnBoardingCompleted>());
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });
  });
}
