part of 'notification_details_dialog.dart';

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          Color.lerp(color, AppColor.whiteColor, .86)!,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: adminFlagForeground(theme, color),
          fontSize: AppFontSizes.size8_5,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = notification.payload;
    final content = payload.isEmpty
        ? S.notificationsDetailsNoPayload
        : const JsonEncoder.withIndent('  ').convert(payload);
    return _InfoCard(
      title: S.notificationsDetailsPayload,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: adminTintedSurfaceColor(theme),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: adminRowBorderColor(theme)),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            content,
            style: TextStyle(
              color: payload.isEmpty
                  ? adminMutedColor(theme)
                  : adminBodyColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_6,
              fontFamily: payload.isEmpty ? null : 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label: title),
          const SizedBox(height: AppSizes.px8),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        color: adminMutedColor(theme),
        fontSize: AppFontSizes.size8_5,
        fontWeight: AppFontWeights.semiBold,
        height: AppTextHeights.line1_4,
        letterSpacing: AppLetterSpacings.space0_2,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_4,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
      ],
    );
  }
}
