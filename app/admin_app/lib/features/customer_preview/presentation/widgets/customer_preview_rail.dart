import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_state.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// السكة الجانبية التي تديرها اللوحة: إعادة القراءة، ولغة الهاتف، والفرع الذي
/// تُقرأ عنه الأسعار والطقس، وعدادات ما وصل، وما لا يعرضه المحاكي صراحةً.
///
/// شاشة الهاتف تُقرأ ولا تُحرَّر من هنا: الأرقام والبنرات تُعدَّل في صفحاتها،
/// والمحاكي يقول ماذا وصل منها إلى الزبون.
class CustomerPreviewRail extends StatelessWidget {
  const CustomerPreviewRail({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLanguageChanged,
    required this.onBranchChanged,
  });

  final CustomerPreviewState state;
  final VoidCallback onRefresh;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<String?> onBranchChanged;

  @override
  Widget build(BuildContext context) {
    final feed = state.feed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminToolbarButton(
          label: S.refresh,
          icon: AppIcons.refresh,
          onPressed: state.isBusy ? null : onRefresh,
          busy: state.isBusy,
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminLabeledValue(
          label: S.previewPhoneLanguage,
          child: AdminSegmentedControl(
            options: [S.arabicLabel, S.englishLabel],
            selected: state.language.isArabic ? S.arabicLabel : S.englishLabel,
            onChanged: (value) => onLanguageChanged(
              value == S.arabicLabel ? AppLanguage.arabic : AppLanguage.english,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminLabeledValue(
          label: S.previewBranch,
          child: _BranchDropdown(state: state, onChanged: onBranchChanged),
        ),
        if (state.branchId != null && state.activeBranch == null) ...[
          const SizedBox(height: AppSpacing.xs),
          _NoteText(text: S.previewBranchUnknown),
        ],
        if (feed != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _RailRow(
            label: S.previewBannersShown,
            value: _count(feed.publishedBanners.length),
          ),
          _RailRow(
            label: S.previewCategoriesShown,
            value: _count(feed.visibleCategories.length),
          ),
          _RailRow(
            label: S.previewProductsShown,
            // الصفحة التي قرأها المحاكي مقابل الكتالوج كله عند القاعدة.
            value:
                '${_count(feed.catalog.length)} / '
                '${_count(state.catalogTotal)}',
          ),
          _RailRow(
            label: S.previewFeaturedShown,
            value: _count(feed.featured.length),
          ),
          _RailRow(
            label: S.previewBundlesShown,
            value: _count(feed.visibleBundles.length),
          ),
          // بلا قراءة طقس لا سطر: السبب تقوله الملاحظة تحتها أو قائمة المقاطع
          // التي لم تُقرأ، لا شرطة فارغة.
          if (feed.hasWeather)
            _RailRow(
              label: S.previewWeather,
              value: _degrees(feed.temperature!),
            ),
        ],
        if (!state.branchHasLocation) ...[
          const SizedBox(height: AppSpacing.sm),
          _NoteText(text: S.previewWeatherNoLocation),
        ],
        if (state.degradedSections.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            S.previewDegradedTitle,
            style: AppFonts.semiBold12(context)
                .copyWith(color: adminHeadingColor(Theme.of(context))),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final section in state.degradedSections)
            _NoteText(text: _sectionLabel(section)),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _NotShownList(),
      ],
    );
  }

  static String _count(int value) => localizeDigits(formatCount(value));

  /// الحرارة تُطبع عددًا صحيحًا بعلامة الدرجة: لا معنى لعشرة آلاف عند الزبون.
  static String _degrees(double temperature) =>
      '${localizeDigits('${temperature.round()}')}°';

  static String _sectionLabel(String section) => switch (section) {
    'bundles' => S.bundles,
    'branches' => S.branches,
    'featured' => S.previewFeaturedShown,
    'weather' => S.previewWeather,
    _ => section,
  };
}

/// اختيار الفرع الذي تُقرأ عنه الأسعار والطقس.
///
/// «بلا فرع» حالة حقيقية لا حشو: القاعدة ترجع الأسعار الأساسية حين لا فرع،
/// وهي الحالة التي يراها الزبون قبل أن يختار فرعًا في تطبيقه.
class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({required this.state, required this.onChanged});

  final CustomerPreviewState state;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(
          S.previewBranchNone,
          style: AppFonts.regular14(context)
              .copyWith(color: adminBodyColor(theme)),
        ),
      ),
      for (final branch in state.branches)
        DropdownMenuItem<String?>(
          value: branch.id,
          child: Text(
            branch.nameFor(state.language),
            style: AppFonts.regular14(context)
                .copyWith(color: adminBodyColor(theme)),
          ),
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: adminCardBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      // الزرّ يحتاج Material حوله، والسكة تُركّب في لوحات مختلفة، فالطبقة
      // تخصّ التحكم نفسه كما في بقية أدوات اللوحة المشتركة.
      child: Material(
        color: AppColor.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: DropdownButton<String?>(
            // الفرع الذي لم تصل قائمة الفروع لا يُختار ولا يُسمّى باسمه،
            // فيُطبع فراغًا وتقول الملاحظة تحته سببه.
            value: state.activeBranch?.id,
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            icon: const Icon(AppIcons.arrowDown01),
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// سطر ملاحظة صغير في السكة: تسمية ما لا يُعرف سببًا في الشاشة.
class _NoteText extends StatelessWidget {
  const _NoteText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppFonts.regular12(context)
            .copyWith(color: adminMutedColor(theme)),
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.regular12(context)
                  .copyWith(color: adminMutedColor(theme)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppFonts.semiBold14(context)
                .copyWith(color: adminHeadingColor(theme)),
          ),
        ],
      ),
    );
  }
}

class _NotShownList extends StatelessWidget {
  const _NotShownList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = <String>[
      S.previewNotShownAccount,
      S.previewNotShownPersonalisation,
      S.previewNotShownTheme,
      S.previewNotShownDetails,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.previewNotShownTitle,
          style: AppFonts.semiBold12(context)
              .copyWith(color: adminHeadingColor(theme)),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              note,
              style: AppFonts.regular12(context)
                  .copyWith(color: adminMutedColor(theme)),
            ),
          ),
      ],
    );
  }
}
