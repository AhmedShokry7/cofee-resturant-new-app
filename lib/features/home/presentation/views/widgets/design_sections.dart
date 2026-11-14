import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_link.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// محرّك رسم أقسام المحتوى الحر في المستند المنشور: نص وعنوان وزر وصورة
/// وفاصل ومسافة وشبكة منتجات وعمود.
///
/// قاعدة الرسم نفسها في كل نوع: خاصية مفقودة أو تالفة تعني قسمًا لا يُرسم
/// (`SizedBox.shrink`) — لا صندوق رمادي محلّ شريط الترشيحات، ولا انهيار.
/// الألوان والقياسات من الرموز المشتركة، والمستند يعدل فوقها فقط.
abstract final class DesignSectionRenderers {
  DesignSectionRenderers._();

  /// رسم قسم بمكوّنه الحقيقي، أو null لما لا يملك خصائصه الدنيا.
  static Widget? build(PublishedSection section) {
    switch (section.type) {
      case DesignWidgetTypes.text:
        return _DesignText(section: section);
      case DesignWidgetTypes.heading:
        return _DesignHeading(section: section);
      case DesignWidgetTypes.button:
        return _DesignButton(section: section);
      case DesignWidgetTypes.image:
        return _DesignImage(section: section);
      case DesignWidgetTypes.divider:
        return _DesignDivider(section: section);
      case DesignWidgetTypes.spacer:
        return _DesignSpacer(section: section);
      case DesignWidgetTypes.productGrid:
        return _DesignProductGrid(section: section);
      case DesignWidgetTypes.column:
        return _DesignColumn(section: section, childBuilder: (child) => build(child));
      default:
        return null;
    }
  }

  /// عمود بأبناء يبنونها المستدعي، فيمرّر المحرّر دالة رسم الأقسام
  /// العامة فتتكرر الأعمدة داخل أعمدة بلا شكل خاص.
  static Widget column(
    PublishedSection section, {
    required Widget? Function(PublishedSection) childBuilder,
  }) => _DesignColumn(section: section, childBuilder: childBuilder);
}

// --------------------------------------------------------------------- مشترك

/// `#RRGGBB` أو `#AARRGGBB` كما تُدقق في القاعدة، أو null.
Color? _hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return null;
  return hex.length == 8 ? Color(value) : Color(0xFF000000 | value);
}

FontWeight? _weight(String? name) {
  // light غير مرفوع في العائلة، فالخفيف يرسم بمنتظم بدل وزن لا ملف له.
  return switch (name) {
    'bold' => AppFontWeights.bold,
    'semibold' => AppFontWeights.semiBold,
    'medium' => AppFontWeights.medium,
    'light' || 'regular' => AppFontWeights.regular,
    _ => null,
  };
}

TextAlign _textAlign(String? alignment) => switch (alignment) {
  'center' => TextAlign.center,
  'end' => TextAlign.end,
  _ => TextAlign.start,
};

double _spacing(String? token, {double fallback = AppSpacing.md}) =>
    switch (token) {
      'none' => AppSpacing.none,
      'xxs' => AppSpacing.xxs,
      'xs' => AppSpacing.xs,
      'sm' => AppSpacing.sm,
      'md' => AppSpacing.md,
      'lg' => AppSpacing.lg,
      'xl' => AppSpacing.xl,
      'xxl' => AppSpacing.xxl,
      'xxxl' => AppSpacing.xxxl,
      _ => fallback,
    };

double _radius(String? token) => switch (token) {
  'sm' => AppRadius.r8,
  'md' => AppRadius.r12,
  'lg' => AppRadius.r16,
  'full' => AppRadius.pill,
  _ => AppRadius.none,
};

void _navigate(String? action, BuildContext context) {
  final route = switch (action) {
    'navigateHome' => MainPage.routeName,
    'navigateSearch' => SearchPage.routeName,
    _ => null,
  };
  // التنقلات التي تحتاج معامِلات (فتح تصنيف أو منتج، السلة والمفضلة
  // تبويبات) لا تُخمَّن: الزر يبقى بلا فعل بدل وجهة مختلقة.
  if (route == null) return;
  Navigator.of(context).pushNamed(route);
}
// ----------------------------------------------------------------------- نص

class _DesignText extends StatelessWidget {
  const _DesignText({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    final text = section.property('text');
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final size =
        section.numberProperty('size') ?? AppFontSizes.size14;
    final color =
        _hexColor(section.property('color')) ?? AppColor.textPrimary;
    return Text(
      text,
      textAlign: _textAlign(section.property('alignment')),
      maxLines: section.numberProperty('maxLines')?.round(),
      overflow: TextOverflow.ellipsis,
      style: AppFonts.regular14(context).copyWith(
        fontSize: size,
        fontWeight: _weight(section.property('weight')),
        color: color,
        height: section.numberProperty('lineHeight') ??
            AppTextHeights.body,
      ),
    );
  }
}

// -------------------------------------------------------------------- عنوان

class _DesignHeading extends StatelessWidget {
  const _DesignHeading({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    final title = section.property('title');
    if (title == null || title.isEmpty) return const SizedBox.shrink();
    final subtitle = section.property('subtitle');
    final linkLabel = section.property('linkLabel');
    // titleSize يُحترم عبر نمط العنوان نفسه لا بمخالفة النظام: نمط
    // عناوين الأقسام مع تعديل الحجم وحده إن طلبه الموظف.
    final titleSize = section.numberProperty('titleSize');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: title,
          titleStyle: titleSize == null
              ? null
              : AppFonts.semiBold16(context)
                  .copyWith(fontSize: titleSize),
          trailing: linkLabel == null || linkLabel.isEmpty
              ? null
              : HomeSectionLink(
                  label: linkLabel,
                  // الإجراءات التي تحتاج معامِلات لا تُخمَّن (نفس قاعدة الزر).
                  onTap: () =>
                      _navigate(section.property('action'), context),
                ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          Text(
            subtitle,
            style: AppFonts.regular12(context).copyWith(
              color: AppColor.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------- زر

class _DesignButton extends StatelessWidget {
  const _DesignButton({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    final label = section.property('label');
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    final style = section.property('style') ?? 'primary';
    final background =
        _hexColor(section.property('color')) ?? AppColor.primaryColor;
    // الزر بأسلوب نصّ يرسم بمنتظم نصّ الشاشة لا بلون نصّ أبيض على شفاف.
    final foreground = _hexColor(section.property('textColor')) ??
        (style == 'primary' ? AppColor.whiteColor : AppColor.textPrimary);
    final radius = _radius(section.property('borderRadius'));
    return Material(
      color: style == 'primary' ? background : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: style == 'outline'
            ? BorderSide(color: background, width: AppSizes.px1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () => _navigate(section.property('action'), context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Text(
            label,
            style: AppFonts.medium14(context).copyWith(
              color: style == 'primary'
                  ? foreground
                  : (style == 'outline' ? background : foreground),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- صورة

class _DesignImage extends StatelessWidget {
  const _DesignImage({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    final imageUrl = section.property('imageUrl');
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    final width = section.numberProperty('width');
    final height = section.numberProperty('height');
    final radius = _radius(section.property('borderRadius'));
    final image = DbImage(
      image: imageUrl,
      // أسماء القيم في المستند نفس أسماء BoxFit، فيقرأها fitFromName
      // مباشرة، وغريبها يرجع إلى cover بلا اهتزاز.
      fit: DbImage.fitFromName(section.property('fit')),
      width: width,
      height: height,
      borderRadius: radius == AppRadius.none
          ? null
          : BorderRadius.circular(radius),
      alignment: switch (section.property('alignment')) {
        'start' => AlignmentDirectional.centerStart.resolve(
          Directionality.of(context),
        ),
        'end' => AlignmentDirectional.centerEnd.resolve(
          Directionality.of(context),
        ),
        _ => Alignment.center,
      },
    );
    return Align(
      alignment: switch (section.property('alignment')) {
        'start' => AlignmentDirectional.centerStart,
        'end' => AlignmentDirectional.centerEnd,
        _ => AlignmentDirectional.center,
      },
      child: image,
    );
  }
}

// ------------------------------------------------------------------ فاصل

class _DesignDivider extends StatelessWidget {
  const _DesignDivider({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: section.numberProperty('thickness') ?? AppSizes.px1,
      color: _hexColor(section.property('color')) ?? AppColor.borderColor,
      indent: _spacing(section.property('inset')),
      endIndent: _spacing(section.property('inset')),
    );
  }
}

// ----------------------------------------------------------------- مسافة

class _DesignSpacer extends StatelessWidget {
  const _DesignSpacer({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    // المسافة قد تكون رمزًا أو رقمًا مباشرًا من المستند.
    final number = section.numberProperty('size');
    return SizedBox(
      height: number ?? _spacing(section.property('size')),
    );
  }
}

// ----------------------------------------------------------- شبكة منتجات

class _DesignProductGrid extends StatelessWidget {
  const _DesignProductGrid({required this.section});

  final PublishedSection section;

  @override
  Widget build(BuildContext context) {
    final dataSource = section.dataSource;
    if (dataSource == DesignDataSources.featured) {
      final products = context.watch<HomeCubit>().state.popular;
      return _grid(context, products);
    }
    if (dataSource == DesignDataSources.recommendations) {
      return BlocBuilder<WeatherCubit, WeatherState>(
        builder: (context, weatherState) {
          final home = context.watch<HomeCubit>().state;
          final favoriteIds = context.select(
            (FavoritesCubit cubit) => cubit.state.ids,
          );
          final weather = weatherState is WeatherLoaded
              ? weatherState.weather
              : null;
          return _grid(context, home.recommendations(
            weather: weather,
            favoriteIds: favoriteIds,
          ));
        },
      );
    }
    // مصدر لا يعرفه الهاتف لا يُختار له شبكة: تخمين أحدهما يخلط بيانات
    // الزبون بشريط لم يطلبها.
    return const SizedBox.shrink();
  }

  Widget _grid(BuildContext context, List<ProductModel> products) {
    final maxItems = section.numberProperty('maxItems')?.round() ?? 20;
    final columns = (section.numberProperty('columns')?.round() ?? 2)
        .clamp(1, 4);
    final shown = products.length > maxItems
        ? products.sublist(0, maxItems)
        : products;
    if (shown.isEmpty) return const SizedBox.shrink();
    // showPrice بلا مفعّل: البطاقة المشتركة ترسم السعر في كل شاشات
    // التطبيق، ومخالفة ذلك هنا تجعل الشبكة بطاقة لا تشبهها.
    final title = section.property('title');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty) ...[
          HomeSectionTitle(title: title),
          const SizedBox(height: AppSpacing.md),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: ProductCard.cardAspectRatio,
          ),
          itemCount: shown.length,
          itemBuilder: (context, index) => ProductCard(product: shown[index]),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- عمود

class _DesignColumn extends StatelessWidget {
  const _DesignColumn({
    required this.section,
    required this.childBuilder,
  });
  final PublishedSection section;

  /// بناء ابن: نفس دالة رسم الأقسام، فتتكرر الأعمدة بلا شكل خاص.
  final Widget? Function(PublishedSection) childBuilder;

  @override
  Widget build(BuildContext context) {
    final rendered = <Widget>[];
    for (var index = 0; index < section.children.length; index++) {
      final child = section.children[index];
      final widget = childBuilder(child);
      if (widget == null) continue;
      if (rendered.isNotEmpty) {
        rendered.add(SizedBox(height: _spacing(section.property('gap'))));
      }
      rendered.add(
        previewSectionWrap(child, pageId: 'home', child: widget),
      );
    }
    if (rendered.isEmpty) return const SizedBox.shrink();
    // حشو العمود بخصائصه هو، فلا يتزداد مع حشو الأب: ابن عمود داخل
    // عمود يرسم بمسافة الأب + مسافة العمود الداخلي لا أكثر.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _spacing(section.property('inset'),
            fallback: AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: switch (section.property('crossAxisAlignment')) {
          'center' => CrossAxisAlignment.center,
          'end' => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: rendered,
      ),
    );
  }
}
