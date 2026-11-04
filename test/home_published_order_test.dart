import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';

import 'support/fake_design_repository.dart';
import 'support/mock_product_repository.dart';

/// المنشور يصل شاشة الزبون: قراءة لا معاينة.
///
/// الاختبار أن الترتيب الذي تنشره اللوحة هو الترتيب الذي يجد الزبون صفحته به،
/// وأن القسم المخفي لا يُبنى أصلًا ولا يحجز مكانًا. لا يثبت هذا قارئُ المستند
/// وحده: الشاشة يجب أن تسأله.
void main() {
  testWidgets('بلا منشور: الصفحة على ترتيبها المكتوب في مصدرها', (
    tester,
  ) async {
    await _pumpHome(tester, FakeDesignRepository());

    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(find.byType(HomeBannerSection), findsOneWidget);
    // البحث تحت الترويسة، كما اليوم.
    expect(
      _top(tester,find.byType(HomeSearchBar)),
      greaterThan(_top(tester,find.byType(HomeHeader))),
    );
  });

  testWidgets('منشور يرتّب الصفحة: الترويسة تنزل تحت البحث', (tester) async {
    await _pumpHome(tester, FakeDesignRepository(_swappedDocument));

    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(
      _top(tester,find.byType(HomeSearchBar)),
      lessThan(_top(tester,find.byType(HomeHeader))),
    );
    // قسمان خارج المستند لم يُرسما: الصفحة تعرض ما نشر لا ترتيب اليوم.
    expect(find.byType(HomeBannerSection), findsNothing);
  });

  testWidgets('منشور يخفي البحث: لا يبنى ولا يحجز مكانه', (tester) async {
    await _pumpHome(tester, FakeDesignRepository(_hiddenSearchDocument));

    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeSearchBar), findsNothing);
  });
}

/// قسمان يعرفهما الهاتف، بغير ترتيب اليوم.
final PublishedDesign _swappedDocument = _design(const <PublishedSection>[
  PublishedSection(id: 'home_search', type: DesignWidgetTypes.searchBar),
  PublishedSection(id: 'home_header', type: DesignWidgetTypes.header),
]);

/// الترويسة ثم بحثٌ أخفاه الموظف: فلا ترويسة وحدها على الصفحة.
final PublishedDesign _hiddenSearchDocument = _design(const <PublishedSection>[
  PublishedSection(id: 'home_header', type: DesignWidgetTypes.header),
  PublishedSection(
    id: 'home_search',
    type: DesignWidgetTypes.searchBar,
    visible: false,
  ),
]);

PublishedDesign _design(List<PublishedSection> sections) =>
    PublishedDesign(schemaVersion: 2, homeSections: sections);

/// أعلى نقطة رُسمت عندها الشاشة: الترتيب عليها يُقاس بها.
double _top(WidgetTester tester, Finder finder) => tester.getRect(finder).top;

/// الصفحة كما يركّبها الإقلاع: كتالوج وهمي ومجليد طقس وجلسة بلا زبون، ومحلّ
/// التصميم ما نشره الموظف.
Future<void> _pumpHome(WidgetTester tester, DesignRepository design) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final catalog = MockProductRepository();
  final home = HomeCubit(repository: catalog);
  final weather = WeatherCubit(_FakeWeatherRepository());
  final favorites = FavoritesCubit(
    repository: catalog,
    favorites: FavoritesRepositoryImpl(),
  );
  final designCubit = DesignCubit(repository: design);
  addTearDown(home.close);
  addTearDown(weather.close);
  addTearDown(favorites.close);
  addTearDown(designCubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: home),
          BlocProvider.value(value: weather),
          BlocProvider.value(value: favorites),
          BlocProvider.value(value: designCubit),
        ],
        child: RepositoryProvider<AuthRepository>.value(
          value: _FakeAuthRepository(),
          child: const HomePage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

class _FakeWeatherRepository implements WeatherRepository {
  @override
  Future<WeatherModel> getCurrentWeather() async =>
      const WeatherModel(temperature: 32);
}

/// الترويسة تقرأ الزبون المسجّل للتحية؛ الجلسة هنا فارغة كما في اختبار الشريط
/// المساعد.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
