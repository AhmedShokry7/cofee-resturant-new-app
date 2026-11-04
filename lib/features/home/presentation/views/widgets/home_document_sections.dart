import 'package:flutter/material.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_single_banner_section.dart';

/// أقسام المستند بترتيبها المنشور، وسقط منها ما لا يعرف الهاتف رسمه.
///
/// قائمة فارغة تعني أن المستند لا يحمل قسمًا يرسمه هذا التطبيق — لا أن الصفحة
/// فارغة: الجسم يرجع عندئذ لترتيبه المكتوب في مصدره.
List<Widget> buildHomeDocumentSections(List<PublishedSection> document) =>
    <Widget>[
      for (final section in document)
        if (buildHomeDocumentSection(section) case Widget widget) widget,
    ];

/// قسم المنشور بمكوّنه الحقيقي في هذا التطبيق، أو null.
///
/// لا بديل عام: عقدة لا يعرفها الهاتف تُترك، لأن صندوقًا رماديًا محلّ شريط
/// الترشيحات يخبر الزبون أن عنده محتوى ولا محتوى، ولأن الوعد أن المحرّر يحرّك
/// مكوّنات الشاشة لا أنها تُستبدل برسوم.
///
/// null كذلك حين أخفى الموظف القسم: الإخفاء قرار ظاهر على الشاشة لا يحجز مكانه.
Widget? buildHomeDocumentSection(PublishedSection section) {
  if (!section.visible) return null;
  switch (section.type) {
    case DesignWidgetTypes.header:
      return const HomeSection(child: HomeHeader());
    case DesignWidgetTypes.searchBar:
      return const HomeSection(child: HomeSearchBar());
    case DesignWidgetTypes.bannerCarousel:
      // شريط البانيرات يملك حشوه بنفسه، كما في ترتيب اليوم.
      return const HomeBannerSection();
    case DesignWidgetTypes.categoryList:
      return const HomeSection(child: HomeCategoriesSection());
    case DesignWidgetTypes.promoBanner:
      return const HomeSection(child: HomeSingleBannerSection());
    case DesignWidgetTypes.bundleList:
      return const HomeSection(child: HomeBundlesSection());
    case DesignWidgetTypes.productStrip:
      return _productStrip(section.dataSource);
    default:
      return null;
  }
}

/// العقدتان «الأكثر طلبًا» و«ترشيحات لك» نوع واحد في المستند، والفصل بمصدر
/// البيانات وحده. مصدر لا يعرفه الهاتف لا يُختار له شريط: تخمين أحدهما يخلط
/// ترشيحات الزبون بصفّ الأكثر مبيعًا.
Widget? _productStrip(String? dataSource) {
  switch (dataSource) {
    case DesignDataSources.featured:
      return const HomeSection(child: HomePopularSection());
    case DesignDataSources.recommendations:
      return const HomeSection(child: HomeRecommendationsSection());
    default:
      return null;
  }
}
