import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/home_personal_bundles_section.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_event_request.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/event_reminder_home_section.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_document_sections.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_loading_view.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomePageBody extends StatelessWidget {
  const HomePageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          // First load: every section is empty, so show skeletons that mirror
          // the real sections instead of a blank page with one spinner.
          if (state.isFirstLoad) {
            return HomeLoadingView(
              showPersonalBundles: SupabaseService.isSignedIn,
            );
          }
          // Total failure: nothing to show and no silent blank page. The
          // message names the degraded sections and offers a retry.
          if (!state.isLoading && state.error != null && state.hasNoContent) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      icon: AppIcons.offline,
                      title: S.homeLoadError,
                      subtitle: state.error!,
                    ),
                    SizedBox(height: AppSpacing.md),
                    CustomBtn(
                      text: S.retry,
                      onPressed: () =>
                          context.read<HomeCubit>().load(forceRefresh: true),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: HomeSection.bodyPadding,
            children: _homeChildren(
              context.watch<DesignCubit>().state.homeSections,
              state.eventReminders
                  .where(
                    (event) => (event.quotedStartAt ?? event.preferredStartAt)
                        .isAfter(DateTime.now()),
                  )
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }
}

/// أقسام الجسم: ترتيب المستند الذي نشره الموظف إن كان، وإلا ترتيب اليوم.
///
/// الفراغ بين قسمين هو الحشو نفسه في الحالتين، فيبقى التبديل بين المنشور
/// والافتراضي تبديل ترتيب لا تبديل مسافات.
List<Widget> _homeChildren(
  List<PublishedSection> document,
  List<CustomerEventRequest> reminders,
) {
  final sections = buildHomeDocumentSections(document);
  final pageSections = sections.isEmpty ? _defaultHomeSections : sections;
  final reminderIndex = _reminderIndex(
    document,
    pageSections,
    sections.isEmpty,
  );
  final children = <Widget>[
    ...pageSections.take(reminderIndex),
    if (reminders.isNotEmpty)
      HomeSection(child: EventReminderHomeSection(reminders: reminders)),
    ...pageSections.skip(reminderIndex),
    const HomeSection(child: HomePersonalBundlesSection()),
  ];
  return <Widget>[
    for (var index = 0; index < children.length; index++) ...<Widget>[
      if (index > 0) SizedBox(height: AppSpacing.lg),
      children[index],
    ],
  ];
}

int _reminderIndex(
  List<PublishedSection> document,
  List<Widget> renderedSections,
  bool isDefault,
) {
  if (isDefault) {
    final index = renderedSections.indexWhere(
      (section) =>
          section is HomeBannerSection &&
          section.placement == BannerPlacement.hero,
    );
    return index < 0 ? 0 : index + 1;
  }
  var sourceIndex = document.indexWhere(
    (section) =>
        section.visible &&
        section.type == DesignWidgetTypes.bannerCarousel &&
        BannerPlacement.fromStorage(section.property('displayLocation')) ==
            BannerPlacement.hero,
  );
  if (sourceIndex < 0) {
    sourceIndex = document.indexWhere(
      (section) =>
          section.visible && section.type == DesignWidgetTypes.bannerCarousel,
    );
  }
  if (sourceIndex < 0) return 0;
  return buildHomeDocumentSections(
    document.take(sourceIndex + 1).toList(growable: false),
  ).length;
}

/// ترتيب الصفحة كما كان قبل الاستوديو، مكتوبًا في مصدره.
///
/// هو ما يُرسم حين لا مستند منشور، وحين لا يحمل المستند صفحة رئيسية يقرأها
/// الهاتف، وحين لا يبقى من أقسامها قسم يُرسم — فالصفحة التي لا بحث فيها ولا
/// بانير لا تسأل الزبون عن طلب، والمحرّر لا يسمح أصلًا بإخفاء عناصرها الثابتة.
/// حرس التطابق في `test/home_section_order_parity_test.dart` يربطه بالمستند
/// الافتراضي في اللوحة، فلا ينقلب أحد الطرفين عن الآخر بغير قرار.
const List<Widget> _defaultHomeSections = <Widget>[
  HomeSection(child: HomeHeader()),
  HomeSection(child: HomeSearchBar()),
  HomeBannerSection(),
  HomeSection(child: HomeCategoriesSection()),
  HomeSection(child: HomePopularSection()),
  HomeSection(child: HomeBannerSection(placement: BannerPlacement.inline)),
  HomeSection(child: HomeRecommendationsSection()),
  HomeSection(child: HomeBundlesSection()),
];
