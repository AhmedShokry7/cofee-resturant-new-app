import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';

/// The documents an answer was read from, named under it.
///
/// Not a "learn more" carousel and not a suggestion: this is provenance. The
/// assistant looked something up, these are the rows it looked at, and the
/// customer is allowed to check them instead of trusting the reply.
///
/// A web row opens in the browser because the whole point of a citation is that
/// the customer can read the page. A shop row (a product, a help article) is
/// already inside the app, so it is named without a link rather than sent to a
/// URL that would only re-open the same screen.
class AssistantSourceList extends StatelessWidget {
  const AssistantSourceList({super.key, required this.sources});

  final List<RetrievedSource> sources;

  /// Three is the most a chat bubble can show before the sources become the
  /// answer. The rest stay in the transcript row.
  static const int _maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final shown = sources
        .take(_maxShown)
        .where((source) => source.title.trim().isNotEmpty)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: [for (final source in shown) _chip(context, source)],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, RetrievedSource source) {
    final label = Text(
      source.title.trim(),
      style: AppFonts.regular12(context).copyWith(color: AppColor.greyColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (source.isLink) ...[
          const Icon(
            AppIcons.externalLink,
            size: 12,
            color: AppColor.greyColor,
          ),
          SizedBox(width: AppSpacing.xxs),
        ],
        Flexible(child: label),
      ],
    );
    if (!source.isLink) return body;
    return Semantics(
      link: true,
      label: '${S.assistantSourcesHeading}: ${source.title}',
      child: InkWell(
        onTap: () => _open(source),
        borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: body,
        ),
      ),
    );
  }

  /// A link the customer asked to read. Failing to open it is not worth a
  /// dialog: the title is still on screen and the answer stands without it.
  Future<void> _open(RetrievedSource source) async {
    final target = source.linkUri;
    if (target == null) return;
    try {
      await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
