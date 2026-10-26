import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/data/models/admin_push_health.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Future<void> showNotificationPushSetupDialog({
  required BuildContext context,
  required AdminPushHealth health,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => NotificationPushSetupDialog(health: health),
  );
}

class NotificationPushSetupDialog extends StatelessWidget {
  const NotificationPushSetupDialog({super.key, required this.health});

  final AdminPushHealth health;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .88, 780.0);
    final url = health.functionUrl?.trim();
    final functionUrl = url == null || url.isEmpty
        ? 'https://<project-ref>.supabase.co/functions/v1/send-push'
        : url;
    return Dialog(
      key: const Key('notification-push-setup-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 700 ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: S.notificationsSetupTitle,
                subtitle: S.notificationsSetupSubtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Intro(message: S.notificationsSetupIntro),
                      const SizedBox(height: 14),
                      _SetupStep(
                        number: 1,
                        title: S.notificationsSetupStep1Title,
                        body: S.notificationsSetupStep1Body,
                        code: _vaultSql,
                      ),
                      const SizedBox(height: 12),
                      _SetupStep(
                        number: 2,
                        title: S.notificationsSetupStep2Title,
                        body: S.notificationsSetupStep2Body,
                        code: _functionUrlSql(functionUrl),
                      ),
                      const SizedBox(height: 12),
                      _SetupStep(
                        number: 3,
                        title: S.notificationsSetupStep3Title,
                        body: S.notificationsSetupStep3Body,
                        code: _deployCommands,
                      ),
                      const SizedBox(height: 12),
                      _SetupStep(
                        number: 4,
                        title: S.notificationsSetupStep4Title,
                        body: S.notificationsSetupStep4Body,
                      ),
                      const SizedBox(height: 14),
                      _Note(message: S.notificationsSetupNote),
                    ],
                  ),
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

const _vaultSql = '''
select vault.create_secret(
  '<strong-random-secret>',
  'push_webhook_secret',
  'Shared secret for the send-push function'
);''';

String _functionUrlSql(String url) =>
    '''
update core.app_settings
   set value = to_jsonb('$url'::text)
 where key = 'push_function_url';''';

const _deployCommands = '''
supabase secrets set PUSH_WEBHOOK_SECRET=<same-random-secret>
supabase secrets set FIREBASE_SERVICE_ACCOUNT='<firebase-service-account-json>'
supabase functions deploy send-push --no-verify-jwt''';

class _Intro extends StatelessWidget {
  const _Intro({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminInfo,
          AppColor.adminInfoSurface,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColor.adminInfo.withValues(
            alpha: adminIsDark(theme) ? .35 : .18,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 16,
            color: adminFlagForeground(theme, AppColor.adminInfo),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: adminFlagForeground(theme, AppColor.adminInfo),
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminWarning,
          AppColor.adminWarningSurface,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColor.adminWarning.withValues(
            alpha: adminIsDark(theme) ? .35 : .18,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLock,
            size: 16,
            color: adminFlagForeground(theme, AppColor.adminWarning),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: adminFlagForeground(theme, AppColor.adminWarning),
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.body,
    this.code,
  });

  final int number;
  final String title;
  final String body;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    AppColor.adminAccent,
                    AppColor.adminAccentSurface,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: adminFlagForeground(theme, AppColor.adminAccent),
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size10,
                        height: AppTextHeights.line1_7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (code != null) ...[
            const SizedBox(height: 9),
            _CodeBlock(code: code!),
          ],
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.notificationsSetupCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkBackground : AppColor.adminTableHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                code,
                style: TextStyle(
                  color: dark ? AppColor.darkText : AppColor.adminBody,
                  fontSize: AppFontSizes.size9_5,
                  height: AppTextHeights.line1_6,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: S.notificationsSetupCopy,
            onPressed: () => _copy(context),
            style: IconButton.styleFrom(
              fixedSize: const Size(30, 30),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCopy01,
              size: 15,
              color: adminMutedColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: adminIsDark(theme)
                ? AppColor.darkBorder
                : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.close),
          ),
        ],
      ),
    );
  }
}
