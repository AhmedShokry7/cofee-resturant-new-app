import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_validator.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// لوحة الحالة: ما يمنع النشر الآن، وإصدارات ما نُشر.
///
/// العيوب تُقرأ من [DesignValidation] نفسها التي يقرأ منها زرّ النشر، فلا
/// قائمة خضراء فوق شجرة لا تُنشر. والإصدارات قائمة محفوظة في القاعدة لا ذكر
/// اللوحة: استعراض إحداها يفتح ملفّها في الهاتف، والرجوع إليها إعادة نشر برقم
/// جديد لا مسح لما بعدها.
class BuilderStatusPanel extends StatelessWidget {
  const BuilderStatusPanel({
    super.key,
    required this.page,
    required this.validation,
    required this.versions,
    required this.inspectedVersionId,
    required this.busy,
    required this.canRestore,
    required this.onInspect,
    required this.onRestore,
  });

  final AppPage page;

  /// نتيجة تدقيق المستند كله؛ null ما دام لا مستند.
  final DesignValidation? validation;
  final List<DesignVersion> versions;

  /// الإصدار المعروض داخل الهاتف الآن، ليُعرف في القائمة بعلامة لا بخمسة أسطر.
  final String? inspectedVersionId;

  /// نشرٌ جارٍ: لا رجوع فوق نشر، فلا إصدارَين يكتبان في وقت واحد.
  final bool busy;

  /// الرجوع إعادة نشر، فهو بصلاحية النشر لا بصلاحية التحرير: من يرى السجل ولا
  /// يملك النشر يقرأ أرقامه وتواريخه وتلمّحه يعترض.
  final bool canRestore;
  final ValueChanged<String> onInspect;
  final ValueChanged<String> onRestore;

  @override
  Widget build(BuildContext context) {
    final issues = validation?.issues ?? const <DesignIssue>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeading(title: S.builderIssues, count: issues.length),
        const SizedBox(height: AppSpacing.sm),
        if (page.lock != AppPageLock.none) ...[
          _Note(text: S.builderPageLockReason(page.lock.name)),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (validation == null)
          _Note(text: S.builderNoSelection)
        else if (issues.isEmpty)
          _Note(text: S.builderIssuesClean, positive: true)
        else
          for (final issue in issues) ...[
            _IssueRow(issue: issue),
            const SizedBox(height: AppSpacing.xs),
          ],
        const SizedBox(height: AppSpacing.lg),
        _GroupHeading(title: S.builderVersions, count: versions.length),
        const SizedBox(height: AppSpacing.sm),
        if (versions.isEmpty)
          _Note(text: S.builderNoVersions)
        else
          for (final version in versions) ...[
            _VersionRow(
              version: version,
              inspected: version.id == inspectedVersionId,
              busy: busy,
              canRestore: canRestore,
              onInspect: () => onInspect(version.id),
              onRestore: () => onRestore(version.id),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

/// عنوان قسم داخل اللوحة، وعدّ ما تحته.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.semiBold14(context)
                .copyWith(color: adminHeadingColor(theme)),
          ),
        ),
        if (count != null)
          Text(
            '$count',
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
      ],
    );
  }
}

/// سطر شرح أو نتيجة بلا إجراء.
class _Note extends StatelessWidget {
  const _Note({required this.text, this.positive = false});

  final String text;

  /// أخضر هادئ: لا عيوب، ولا يُترك الموظف يقرأ «فارغ» كما لو كان خطأ.
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = positive
        ? adminFlagForeground(theme, AppColor.trendPositive)
        : adminMutedColor(theme);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          positive ? AppIcons.checkmarkCircle01 : AppIcons.informationCircle,
          size: AppDimensions.iconSizeSm,
          color: tone,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: tone,
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.regular,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
      ],
    );
  }
}

/// عيب واحد: قاعدته بلغة اللوحة، ثم عقده وتفصيله كما أخرجهما المدقّق.
class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final DesignIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final where = <String>[
      if (issue.page != null) issue.page!.key,
      if (issue.nodeId != null) issue.nodeId!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: adminRowBorderColor(theme)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.builderIssue(issue.code.name),
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
          if (where.isNotEmpty || issue.detail.isNotEmpty)
            Text(
              <String>[
                where,
                issue.detail,
              ].where((part) => part.isNotEmpty).join(' — '),
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.regular,
                height: AppTextHeights.line1_4,
              ),
            ),
        ],
      ),
    );
  }
}

/// سطر إصدار: رقمه وتاريخه، واستعراضه في الهاتف والرجوع إليه.
class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.inspected,
    required this.busy,
    required this.canRestore,
    required this.onInspect,
    required this.onRestore,
  });

  final DesignVersion version;
  final bool inspected;
  final bool busy;
  final bool canRestore;
  final VoidCallback onInspect;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: inspected ? adminTintedSurfaceColor(theme) : null,
        border: Border.all(
          color: inspected ? AppColor.adminAccent : adminRowBorderColor(theme),
          width: inspected
              ? AppDimensions.builderIndicatorStroke
              : AppSizes.px1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.builderVersionLabel(version.number),
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ),
              Text(
                formatDateTime(version.publishedAt),
                style: TextStyle(
                  color: adminDateColor(theme),
                  fontSize: AppFontSizes.size9,
                  fontWeight: AppFontWeights.regular,
                ),
              ),
            ],
          ),
          if (version.note != null && version.note!.isNotEmpty)
            Text(
              version.note!,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.regular,
                height: AppTextHeights.line1_4,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onInspect, child: Text(S.builderInspect)),
              const SizedBox(width: AppSpacing.xxs),
              Tooltip(
                message: canRestore
                    ? S.builderRestore
                    : S.builderPublishNeedsPermission,
                child: TextButton(
                  onPressed: !busy && canRestore ? onRestore : null,
                  child: Text(S.builderRestore),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
