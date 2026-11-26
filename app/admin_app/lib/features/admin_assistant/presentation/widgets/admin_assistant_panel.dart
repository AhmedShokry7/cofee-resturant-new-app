import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/admin_assistant/presentation/manager/admin_assistant_cubit.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

class AdminAssistantPanel extends StatefulWidget {
  const AdminAssistantPanel({
    super.key,
    this.session,
    required this.onClose,
  });

  final AdminSession? session;
  final VoidCallback onClose;

  @override
  State<AdminAssistantPanel> createState() => _AdminAssistantPanelState();
}

class _AdminAssistantPanelState extends State<AdminAssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    context.read<AdminAssistantCubit>().send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 18,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            _header(theme),
            _scopeNotice(theme),
            Expanded(
              child: BlocBuilder<AdminAssistantCubit, AdminAssistantState>(
                builder: (context, state) {
                  if (state.messages.isEmpty) {
                    return _welcome(theme, isArabic);
                  }
                  return ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      for (final message in state.messages)
                        _message(message, theme),
                      if (state.isSending) _typing(theme),
                      if (state.hasError) _error(theme, state.failure),
                    ],
                  );
                },
              ),
            ),
            _composer(theme),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) => Container(
    color: theme.colorScheme.surface,
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColor.adminAccentSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: Image.asset(
              AppImages.aiBot,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.adminAssistantTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                S.adminAssistantSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: S.close,
          onPressed: widget.onClose,
          icon: const AppIcon(AppIcons.cancel01, size: 17),
        ),
      ],
    ),
  );

  Widget _scopeNotice(ThemeData theme) => Container(
    width: double.infinity,
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    color: theme.colorScheme.surfaceContainerHighest,
    child: Text(
      S.adminAssistantScopeNotice,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _welcome(ThemeData theme, bool isArabic) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppImages.aiBot,
            width: 56,
            height: 56,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            S.adminAssistantWelcome,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _suggestionGrid(isArabic),
        ],
      ),
    ),
  );

  Widget _suggestionGrid(bool isArabic) => LayoutBuilder(
    builder: (context, constraints) {
      final labels = isArabic
          ? [
              'وصف منتج',
              'قارن لاتيه وكابتشينو',
              'مبيعات اليوم؟',
              'مواد منخفضة المخزون؟',
            ]
          : [
              'Product description',
              'Compare latte & cappuccino',
              'Today’s sales?',
              'Low stock materials?',
            ];
      final columns = constraints.maxWidth >= 330 ? 2 : 1;
      final gap = AppSpacing.sm;
      final width = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final label in labels)
            SizedBox(width: width, child: _suggestion(label)),
        ],
      );
    },
  );

  Widget _suggestion(String text) => OutlinedButton(
    onPressed: () {
      _input.text = text;
      _send();
    },
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(38),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      foregroundColor: AppColor.adminAccent,
      side: const BorderSide(color: AppColor.adminControlBorder),
    ),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  Widget _message(AdminAssistantMessage message, ThemeData theme) {
    final user = message.isUser;
    return Align(
      alignment: user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: user
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: _messageBubble(message.text, user, theme)),
                const SizedBox(width: AppSpacing.sm),
                AdminAvatarImage(
                  url: widget.session?.avatarUrl,
                  size: 32,
                  fallbackText: widget.session == null
                      ? null
                      : _initials(widget.session!.fullName),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipOval(
                  child: Image.asset(
                    AppImages.aiBot,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: _messageBubble(message.text, user, theme)),
              ],
            ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final words = parts.where((part) => part.isNotEmpty).take(2);
    final initials = words.map((word) => word.substring(0, 1)).join();
    return initials.isEmpty ? '?' : initials;
  }

  Widget _messageBubble(String text, bool user, ThemeData theme) => Container(
    constraints: const BoxConstraints(maxWidth: 310),
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: user
          ? AppColor.adminAccent
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: user ? AppColor.whiteColor : theme.colorScheme.onSurface,
        height: 1.45,
      ),
    ),
  );

  Widget _typing(ThemeData theme) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.asset(
              AppImages.aiBot,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _error(ThemeData theme, AdminAssistantFailure failure) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      switch (failure) {
        AdminAssistantFailure.provider => S.adminAssistantProviderFailure,
        AdminAssistantFailure.session => S.adminAssistantSessionFailure,
        AdminAssistantFailure.none ||
        AdminAssistantFailure.network => S.adminAssistantFailure,
      },
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    ),
  );

  Widget _composer(ThemeData theme) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: S.adminAssistantInputHint,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          BlocBuilder<AdminAssistantCubit, AdminAssistantState>(
            builder: (context, state) => IconButton.filled(
              tooltip: S.adminAssistantSend,
              onPressed: state.isSending ? null : _send,
              icon: state.isSending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(
                      AppIcons.arrowUp01,
                      color: AppColor.whiteColor,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
