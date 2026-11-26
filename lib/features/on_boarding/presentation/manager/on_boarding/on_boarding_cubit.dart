import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';

part 'on_boarding_state.dart';

/// Everything the onboarding decides: which slide is showing, when the customer
/// has reached the end, and which screen comes after it.
///
/// The screen never picks a route and never writes a marker; both used to be
/// reactions the widgets took on their own.
///
/// الشرائح ووقت الانتقال يملكهما المستند المنشور: الشرائح تُعطى عند
/// الإنشاء من قارئ المستند، ووقت الانتقال عقدة `onboarding.transition`
/// — مدة الحركة (`durationMs`) والتقديم التلقائي (`seconds`). ما لم
/// ينشره الموظف يعني حركة اليوم، ولا تقديم تلقائي.
class OnBoardingCubit extends Cubit<OnBoardingState> {
  OnBoardingCubit({
    this.session = const SessionRepository(),
    List<OnBoardingModel>? slides,
    Duration? slideDuration,
    this._autoAdvance,
  }) : _slides = slides ?? onBoardingSlides(),
       _slideDuration = slideDuration ?? MotionTokens.entrance,
       pageController = PageController(initialPage: _firstPage),
       super(const OnBoardingInitial()) {
    _startAutoTimer();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (_autoAdvance != null && _slides.length > 1) {
      _autoTimer = Timer.periodic(_autoAdvance!, (_) => _autoStep());
    }
  }

  /// استقبال المستند الجديد حيًّا: شرائح ووقت انتقال جديدان يُطبّقان على
  /// الشاشة المعروضة الآن بلا إعادة فتحها — هذا ما يراه الموظف في المعاينة
  /// حين يعدّل التعريف وهو يشاهده.
  void updateDesign({
    required List<OnBoardingModel> slides,
    required Duration? slideDuration,
    required Duration? autoAdvance,
  }) {
    if (slides.isEmpty) return;
    final sameSlides =
        slides.length == _slides.length &&
        slides.asMap().entries.every(
          (e) =>
              e.value.image == _slides[e.key].image &&
              e.value.title == _slides[e.key].title &&
              e.value.body == _slides[e.key].body,
        );
    final sameDuration = slideDuration == _slideDuration;
    final sameAdvance = autoAdvance == _autoAdvance;
    if (sameSlides && sameDuration && sameAdvance) return;
    _slides = slides;
    _slideDuration = slideDuration ?? MotionTokens.entrance;
    _autoAdvance = autoAdvance;
    if (_currentPage >= _slides.length) {
      _currentPage = _slides.length - 1;
    }
    _startAutoTimer();
    // إشعار يعيد بناء الشرائح والنقاط على الشاشة المعروضة.
    emit(OnBoardingPageChanged(currentPage: _currentPage));
  }

  /// Where the "the onboarding is done" marker is written.
  final SessionRepository session;

  /// The controller the PageView is driven by, so the buttons can step the
  /// slides without holding a second copy of the index.
  final PageController pageController;

  /// A slide move goes both ways, so it eases in as well as out; that is not
  /// the one-way arrival [MotionTokens.entranceCurve] describes.
  static const Curve _slideCurve = Curves.easeInOut;

  static const int _firstPage = 0;

  /// الشرائح كما قرأها المستند، أو شرائح المصدر حين لا مستند يقرؤه.
  List<OnBoardingModel> _slides;

  /// مدة الحركة بين الشرائح، من المستند أو أصلها.
  Duration _slideDuration;

  /// تقديم الشرائح تلقائيًا كل مدة، أو null لمن لم ينشر وقتًا.
  Timer? _autoTimer;

  Duration? _autoAdvance;

  int _currentPage = _firstPage;

  /// The slide the customer is looking at. Only [changePage] writes it, because
  /// the PageView is the thing that knows where it has stopped.
  int get currentPage => _currentPage;

  /// The slides the page view walks through.
  List<OnBoardingModel> get slides => List.unmodifiable(_slides);

  /// مدة حركة الانتقال الحالية بين الشرائح.
  Duration get slideDuration => _slideDuration;

  /// How many slides there are to walk through.
  int get slideCount => _slides.length;

  /// The PageView settled on a different slide.
  void changePage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    emit(OnBoardingPageChanged(currentPage: page));
  }

  /// Shows the next slide, or ends the onboarding on the last one.
  Future<void> next() async {
    if (_currentPage < slideCount - 1) {
      await pageController.nextPage(
        duration: _slideDuration,
        curve: _slideCurve,
      );
      return;
    }
    await complete();
  }

  /// Shows the previous slide. The index is not touched here: the PageView
  /// reports where it stopped, and this method only asks for the move.
  void back() {
    if (_currentPage > _firstPage) {
      pageController.previousPage(duration: _slideDuration, curve: _slideCurve);
    }
  }

  /// خطوة التقديم التلقائي: شريحة أمامى، وآخر شريحة تُنهي التعريف.
  Future<void> _autoStep() async {
    if (_currentPage < slideCount - 1) {
      await next();
      return;
    }
    _autoTimer?.cancel();
    await complete();
  }

  /// Records that the customer is done with the onboarding, whether they
  /// reached the last slide or skipped it, and names the screen after it.
  ///
  /// The marker is confirmed, but the exit never waits for it: storage that
  /// cannot answer must not trap a customer inside a tutorial.
  Future<void> complete() async {
    _autoTimer?.cancel();
    final saved = await session.markOnboardingSkippedConfirmed();
    if (!saved) {
      debugPrint('[OnBoarding] completion marker could not be persisted.');
    }
    if (isClosed) return;
    emit(const OnBoardingCompleted(nextRoute: AuthPage.routeName));
  }

  @override
  Future<void> close() {
    _autoTimer?.cancel();
    pageController.dispose();
    return super.close();
  }
}
