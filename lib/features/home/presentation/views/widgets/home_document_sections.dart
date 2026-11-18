import 'package:flutter/material.dart';

import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_bundles_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_recommendations_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_section_chrome.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/design_sections.dart';
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
        if (buildHomeDocumentSection(section) case Widget widget)
          previewSectionWrap(
            section,
            pageId: 'home',
            // أقسام المحتوى الحر لا تحشو نفسها: أعلى الصفحة يغلّفها
            // بحشو الصفحة. العمود وحده يستثنى، لأنه يحشو نفسه بـ inset.
            child: _isFreeContent(section.type)
                ? HomeSection(child: widget)
                : widget,
          ),
    ];

/// هل النوع من محتوى حر يرسم عاريًا ولا يحشو نفسه.
bool _isFreeContent(String type) => switch (type) {
  DesignWidgetTypes.text ||
  DesignWidgetTypes.heading ||
  DesignWidgetTypes.button ||
  DesignWidgetTypes.image ||
  DesignWidgetTypes.divider ||
  DesignWidgetTypes.spacer ||
  DesignWidgetTypes.productGrid => true,
  _ => false,
};

/// قسم المنشور بمكوّنه الحقيقي في هذا التطبيق، أو null.
///
/// لا بديل عام: عقدة لا يعرفها الهاتف تُترك، لأن صندوقًا رماديًا محلّ شريط
/// الترشيحات يخبر الزبون أن عنده محتوى ولا محتوى، ولأن الوعد أن المحرّر يحرّك
/// مكوّنات الشاشة لا أنها تُستبدل برسوم.
///
/// null كذلك حين أخفى الموظف القسم: الإخفاء قرار ظاهر على الشاشة لا يحجز مكانه.
///
/// كل قسم يُغلَّف بـ [DesignSectionChrome]: كل خصائصه المقاسة (العرض،
/// الحواف، الخلفية، الحدّ، الزوايا، الظلّ، الشفافية) تمرّ من مستند التصميم
/// إلى التطبيق كما كتبها الموظف، وغيابها يترك القسم كما كان.
Widget? buildHomeDocumentSection(PublishedSection section) {
  if (!section.visible) return null;
  final Widget? native = switch (section.type) {
    DesignWidgetTypes.header => HomeSection(
      child: HomeHeader(
        greeting: section.localizedText('greeting')?.trim().isNotEmpty == true
            ? section.localizedText('greeting')!.trim()
            : null,
        question: section.localizedText('question')?.trim().isNotEmpty == true
            ? section.localizedText('question')!.trim()
            : null,
        showGreeting: section.flagProperty('showGreeting', fallback: true),
        showLoyaltyPill: section.flagProperty(
          'showLoyaltyPill',
          fallback: true,
        ),
        showNotification: section.flagProperty(
          'showNotification',
          fallback: true,
        ),
      ),
    ),
    DesignWidgetTypes.searchBar => HomeSection(
      child: HomeSearchBar(
        hintText: section.localizedText('hint')?.trim().isNotEmpty == true
            ? section.localizedText('hint')!.trim()
            : null,
      ),
    ),
    DesignWidgetTypes.bannerCarousel =>
      // شريط البانيرات يملك حشوه بنفسه، كما في ترتيب اليوم. المفتاح يُعيد
      // بناء الشريط عند تغيّر `autoplay` فلا يبقى المؤقت قديمًا.
      HomeBannerSection(
        key: ValueKey(
          'banner_${section.id}_${section.flagProperty('autoplay', fallback: true)}_${section.numberProperty('height')}_${section.numberProperty('bannerDraftCount')}',
        ),
        autoplay: section.flagProperty('autoplay', fallback: true),
        height: section.numberProperty('height'),
        previewBanners: _draftBanners(section),
        radius: _radius(section.property('radius')),
        showDots: section.flagProperty('showDots', fallback: true),
      ),
    DesignWidgetTypes.categoryList => HomeSection(
      child: HomeCategoriesSection(
        title: _localizedTitle(section),
        showTitle: section.flagProperty('showTitle', fallback: true),
        titleStyle: _titleStyle(section),
      ),
    ),
    DesignWidgetTypes.promoBanner => HomeSection(
      child: HomeSingleBannerSection(
        bannerIndex: section.numberProperty('bannerIndex')?.round() ?? 1,
        height: section.numberProperty('height'),
        radius: _radius(section.property('radius')),
      ),
    ),
    DesignWidgetTypes.bundleList => HomeSection(
      child: HomeBundlesSection(
        title: _localizedTitle(section),
        showTitle: section.flagProperty('showTitle', fallback: true),
        titleStyle: _titleStyle(section),
      ),
    ),
    DesignWidgetTypes.productStrip => _productStrip(section),
    DesignWidgetTypes.productGrid =>
      // شبكة المنتجات ترسم عارية مثل المحتوى الحر، فتُغلّف أعلى الصفحة
      // أو يحشوها عمودها بـ inset.
      DesignSectionRenderers.build(section),
    DesignWidgetTypes.column =>
      // العمود يحشو نفسه بخاصيته `inset` (افتراض الأدمن md)، وابناه
      // يبنون بنفس دالة رسم الأقسام فتتكرر الأعمدة داخل أعمدة بلا شكل
      // خاص، وابن حقيقي (شريط بانر) يبقى بنفس تخطيطه.
      DesignSectionRenderers.column(
        section,
        childBuilder: buildHomeDocumentSection,
      ),
    DesignWidgetTypes.row => DesignSectionRenderers.build(section),
    DesignWidgetTypes.text ||
    DesignWidgetTypes.heading ||
    DesignWidgetTypes.button ||
    DesignWidgetTypes.image ||
    DesignWidgetTypes.divider ||
    DesignWidgetTypes.spacer =>
      // عارية: الحشو قرار من يجمعها. في أعلى الصفحة يغلّفها
      // buildHomeDocumentSections، وابن عمود يحشوها عموده بـ inset.
      DesignSectionRenderers.build(section),
    _ => null,
  };
  if (native == null) return null;
  return DesignSectionChrome(section: section, child: native);
}

/// العقدتان «الأكثر طلبًا» و«ترشيحات لك» نوع واحد في المستند، والفصل بمصدر
/// البيانات وحده. مصدر لا يعرفه الهاتف لا يُختار له شريط: تخمين أحدهما يخلط
/// ترشيحات الزبون بصفّ الأكثر مبيعًا.
/// بنرات مؤقتة يحملها مستند المحرر كخصائص أولية؛ لا تُقرأ ولا تُكتب في
/// قائمة بنرات العميل المنشورة. الغياب يعيد السلوك الطبيعي لقائمة العميل.
List<BannerModel>? _draftBanners(PublishedSection section) {
  final count = section.numberProperty('bannerDraftCount');
  if (count == null) return null;
  return [
    for (var index = 0; index < count.round().clamp(0, 10); index++)
      BannerModel(
        id: 'preview_${section.id}_$index',
        image: section.property('bannerDraft_${index}_image') ?? '',
        titleAr: 'بانر معاينة ${index + 1}',
        titleEn: 'Preview banner ${index + 1}',
        target: BannerTarget.fromStorage(
          section.property('bannerDraft_${index}_targetType') ?? 'none',
        ),
        targetId: section.property('bannerDraft_${index}_targetId'),
        targetUrl: section.property('bannerDraft_${index}_targetUrl'),
      ),
  ];
}

String? _localizedTitle(PublishedSection section) =>
    section.localizedText('title');

Widget? _productStrip(PublishedSection section) {
  final maxItems = section.numberProperty('maxItems')?.round() ?? 10;
  final showPrice = section.flagProperty('showPrice', fallback: true);
  final showViewMore = section.flagProperty('showViewMore', fallback: true);
  switch (section.dataSource) {
    case DesignDataSources.featured:
      return HomeSection(
        child: HomePopularSection(
          title: _localizedTitle(section),
          maxItems: maxItems,
          showPrice: showPrice,
          showViewMore: showViewMore,
          titleStyle: _titleStyle(section),
        ),
      );
    case DesignDataSources.recommendations:
      return HomeSection(
        child: HomeRecommendationsSection(
          title: _localizedTitle(section),
          maxItems: maxItems,
          showPrice: showPrice,
          showViewMore: showViewMore,
          titleStyle: _titleStyle(section),
        ),
      );
    default:
      return null;
  }
}

/// نمط العنوان من مستند التصميم؛ الغائب يعني نمط القسم كما كان.
TextStyle? _titleStyle(PublishedSection section) {
  final size = section.numberProperty('titleSize');
  final color = _hexColor(section.property('titleColor'));
  if (size == null && color == null) return null;
  return TextStyle(
    fontSize: size ?? 18,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

Color? _hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return null;
  return hex.replaceFirst('#', '').length == 8
      ? Color(value)
      : Color(0xFF000000 | value);
}

double _radius(String? token) => switch (token) {
  'sm' => AppRadius.r8,
  'md' => AppRadius.r12,
  'lg' => AppRadius.r16,
  'full' => AppRadius.pill,
  _ => AppRadius.none,
};
