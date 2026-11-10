import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/ai_knowledge/data/ai_knowledge_repository.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// مركز إعداد المساعد: اتصال النموذج، أسلوب الرد، ومحتوى المعرفة المنشور.
/// المفاتيح تُرسل مرة واحدة إلى دالة إدارية وتُحفظ في Vault؛ لا تُقرأ ثانية.
class AiKnowledgePage extends StatefulWidget {
  const AiKnowledgePage({
    super.key,
    required this.searchController,
    required this.canManage,
    this.repository,
  });

  final AdminSearchController searchController;
  final bool canManage;
  final AiKnowledgeRepository? repository;

  @override
  State<AiKnowledgePage> createState() => _AiKnowledgePageState();
}

class _AiKnowledgePageState extends State<AiKnowledgePage>
    with SingleTickerProviderStateMixin {
  late final AiKnowledgeRepository _repository;
  late final TabController _tabs;
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _prompt = TextEditingController();
  final _fallback = TextEditingController();
  String _search = '';
  String _provider = 'gemini';
  String _tone = 'friendly';
  int _maxReplyChars = 700;
  int _articleLoadEpoch = 0;
  bool _enabled = true;
  bool _busy = false;
  bool _loading = true;
  bool _hasKey = false;
  String? _error;
  List<Map<String, dynamic>> _articles = const [];
  List<Map<String, dynamic>> _examples = const [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AiKnowledgeRepository();
    _tabs = TabController(length: 3, vsync: this);
    widget.searchController.bind(_onSearch);
    _load();
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    _tabs.dispose();
    _model.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _prompt.dispose();
    _fallback.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() => _search = value.trim());
    _loadArticles();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _repository.loadConfig();
      if (!mounted) return;
      _applyConfig(config);
      await Future.wait([_loadArticles(), _loadExamples()]);
    } catch (error) {
      if (mounted) setState(() => _error = adminErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyConfig(Map<String, dynamic> config) {
    _provider = _text(config['provider'], 'gemini');
    _model.text = _text(config['model'], 'gemini-3.8-flash');
    _baseUrl.text = _text(config['base_url'], '');
    _prompt.text = _text(config['system_prompt'], '');
    _fallback.text = _text(config['fallback_reply'], '');
    _tone = _text(config['tone'], 'friendly');
    _maxReplyChars = _integer(config['max_reply_chars'], 700).clamp(200, 2000);
    _enabled = config['enabled'] != false;
    _hasKey = config['has_api_key'] == true;
  }

  Future<void> _loadArticles() async {
    final epoch = ++_articleLoadEpoch;
    try {
      final rows = await _repository.loadArticles(search: _search);
      if (mounted && epoch == _articleLoadEpoch) {
        setState(() => _articles = rows);
      }
    } catch (error) {
      if (mounted && epoch == _articleLoadEpoch) {
        setState(() => _error = adminErrorMessage(error));
      }
    }
  }

  Future<void> _loadExamples() async {
    final rows = await _repository.loadReplyExamples();
    if (mounted) setState(() => _examples = rows);
  }

  Future<void> _saveConfig() async {
    if (!widget.canManage || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final pendingKey = _apiKey.text.trim();
    try {
      await _repository.saveConfig(
        provider: _provider,
        model: _model.text.trim(),
        baseUrl: _baseUrl.text.trim(),
        systemPrompt: _prompt.text.trim(),
        tone: _tone,
        maxReplyChars: _maxReplyChars,
        fallbackReply: _fallback.text.trim(),
        enabled: _enabled,
        apiKey: pendingKey.isEmpty ? null : pendingKey,
      );
      _apiKey.clear();
      await _load();
      if (mounted) _notice(S.aiKnowledgeSaved);
    } catch (error) {
      if (mounted) setState(() => _error = adminErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editArticle([Map<String, dynamic>? row]) async {
    if (!widget.canManage) return;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _KnowledgeArticleDialog(article: row),
    );
    if (draft == null) return;
    setState(() => _busy = true);
    try {
      await _repository.saveArticle(draft);
      await _loadArticles();
      if (mounted) _notice(S.aiKnowledgeArticleSaved);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteArticle(Map<String, dynamic> article) async {
    if (!widget.canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.aiKnowledgeDeleteTitle),
        content: Text(_text(article['title_ar'], '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _repository.deleteArticle(_text(article['id'], ''));
      await _loadArticles();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editReplyExample([Map<String, dynamic>? example]) async {
    if (!widget.canManage) return;
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReplyExampleDialog(example: example),
    );
    if (draft == null) return;
    setState(() => _busy = true);
    try {
      await _repository.saveReplyExample(draft);
      await _loadExamples();
      if (mounted) _notice(S.aiKnowledgeExampleSaved);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteReplyExample(Map<String, dynamic> example) async {
    if (!widget.canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.aiKnowledgeDeleteTitle),
        content: Text(_text(example['intent'], '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _repository.deleteReplyExample(_text(example['id'], ''));
      await _loadExamples();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: S.aiKnowledge,
          subtitle: S.aiKnowledgeSubtitle,
          progress: _busy || _loading ? 0 : null,
          progressLabel: _busy ? S.saving : null,
          actions: [
            CustomBtn(
              text: S.refresh,
              variant: BtnVariant.outlined,
              onPressed: _load,
            ),
          ],
        ),
        if (_error != null) _InlineError(message: _error!),
        const SizedBox(height: AppSpacing.md),
        _statusCard(),
        const SizedBox(height: AppSpacing.md),
        _tabBar(),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _loading
              ? const AdminLoadingView()
              : TabBarView(
                  controller: _tabs,
                  children: [_settingsTab(), _knowledgeTab(), _replyTab()],
                ),
        ),
      ],
    ),
  );

  Widget _statusCard() {
    final theme = Theme.of(context);
    return AdminSectionCard(
      title: S.aiKnowledgeStatus,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _enabled && _hasKey
                  ? AppColor.adminAccentSurface
                  : AppColor.adminWarningSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              _enabled && _hasKey ? AppIcons.sparkles : AppIcons.alert01,
              color: _enabled && _hasKey
                  ? AppColor.adminAccent
                  : AppColor.adminWarning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enabled && _hasKey
                      ? S.aiKnowledgeReady
                      : S.aiKnowledgeNeedsSetup,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size15,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${_providerLabel(_provider)} • ${_model.text} • ${_articles.length} ${S.aiKnowledgeArticlesCount}',
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size11_5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (widget.canManage)
            Switch.adaptive(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
        ],
      ),
    );
  }

  Widget _tabBar() => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: adminCardBorderColor(Theme.of(context))),
    ),
    child: TabBar(
      controller: _tabs,
      isScrollable: true,
      tabs: [
        Tab(
          text: S.aiKnowledgeSettingsTab,
          icon: const Icon(AppIcons.settings01),
        ),
        Tab(text: S.aiKnowledgeArticlesTab, icon: const Icon(AppIcons.note01)),
        Tab(
          text: S.aiKnowledgeRepliesTab,
          icon: const Icon(AppIcons.comment01),
        ),
      ],
    ),
  );

  Widget _settingsTab() => ListView(
    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
    children: [
      _section(
        title: S.aiKnowledgeProviderTitle,
        subtitle: S.aiKnowledgeProviderHint,
        child: Column(
          children: [
            _fieldRow([
              _dropdown(
                label: S.aiKnowledgeProvider,
                value: _provider,
                values: const [
                  'gemini',
                  'groq',
                  'openrouter',
                  'openai',
                  'custom',
                ],
                onChanged: (value) => setState(() {
                  _provider = value;
                  if (value == 'gemini') {
                    _baseUrl.text = 'https://generativelanguage.googleapis.com/v1beta/openai';
                    if (_model.text.isEmpty) _model.text = 'gemini-3.8-flash';
                  } else if (value == 'groq') {
                    _baseUrl.text = 'https://api.groq.com/openai/v1';
                    if (_model.text.isEmpty) {
                      _model.text = 'openai/gpt-oss-120b';
                    }
                  } else if (value == 'openrouter') {
                    _baseUrl.text = 'https://openrouter.ai/api/v1';
                    if (_model.text.isEmpty) _model.text = 'openrouter/free';
                  } else if (value == 'openai') {
                    _baseUrl.text = 'https://api.openai.com/v1';
                    if (_model.text.isEmpty) _model.text = 'gpt-4o-mini';
                  }
                }),
              ),
              _textField(_model, S.aiKnowledgeModel),
            ]),
            if (_provider == 'custom' || _provider == 'openai') ...[
              const SizedBox(height: AppSpacing.md),
              _textField(_baseUrl, S.aiKnowledgeBaseUrl),
            ],
            const SizedBox(height: AppSpacing.md),
            _secretField(),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _hasKey ? S.aiKnowledgeKeyConfigured : S.aiKnowledgeKeyMissing,
                style: TextStyle(
                  color: _hasKey ? AppColor.adminAccent : AppColor.adminWarning,
                  fontSize: AppFontSizes.size11_5,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CustomBtn(
          text: S.aiKnowledgeSaveSettings,
          leadingIcon: const Icon(AppIcons.tick01),
          isLoading: _busy,
          enabled: widget.canManage && !_busy,
          onPressed: _saveConfig,
        ),
      ),
    ],
  );

  Widget _knowledgeTab() => AdminSectionCard(
    title: S.aiKnowledgeArticlesTab,
    subtitle: S.aiKnowledgeArticlesHint,
    trailing: widget.canManage
        ? CustomBtn(
            text: S.aiKnowledgeAddArticle,
            leadingIcon: const Icon(AppIcons.add01),
            onPressed: () => _editArticle(),
          )
        : null,
    child: _articles.isEmpty
        ? AdminEmptyState(
            icon: AppIcons.note01,
            message: S.aiKnowledgeNoArticles,
            hint: S.aiKnowledgeArticlesHint,
            action: widget.canManage
                ? CustomBtn(
                    text: S.aiKnowledgeAddArticle,
                    leadingIcon: const Icon(AppIcons.add01),
                    onPressed: () => _editArticle(),
                  )
                : null,
          )
        : ListView.separated(
            itemCount: _articles.length,
            shrinkWrap: true,
            separatorBuilder: (_, _) => const Divider(height: AppSpacing.xl),
            itemBuilder: (context, index) {
              final article = _articles[index];
              return _ArticleTile(
                article: article,
                canManage: widget.canManage,
                onEdit: () => _editArticle(article),
                onDelete: () => _deleteArticle(article),
              );
            },
          ),
  );

  Widget _replyTab() => ListView(
    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
    children: [
      AdminSectionCard(
        title: S.aiKnowledgeRepliesTitle,
        subtitle: S.aiKnowledgeRepliesHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldRow([
              _dropdown(
                label: S.aiKnowledgeTone,
                value: _tone,
                values: const ['friendly', 'professional', 'casual'],
                onChanged: (value) => setState(() => _tone = value),
              ),
              _dropdown(
                label: S.aiKnowledgeReplyLength,
                value: '$_maxReplyChars',
                values: const ['350', '700', '1200', '1800'],
                onChanged: (value) =>
                    setState(() => _maxReplyChars = int.tryParse(value) ?? 700),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            _textArea(_prompt, S.aiKnowledgeSystemPrompt, minLines: 7),
            const SizedBox(height: AppSpacing.md),
            _textArea(_fallback, S.aiKnowledgeFallbackReply, minLines: 3),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CustomBtn(
                text: S.aiKnowledgeSaveSettings,
                isLoading: _busy,
                enabled: widget.canManage && !_busy,
                onPressed: _saveConfig,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AdminSectionCard(
        title: S.aiKnowledgeExamplesTitle,
        subtitle: S.aiKnowledgeExamplesHint,
        trailing: widget.canManage
            ? CustomBtn(
                text: S.aiKnowledgeAddExample,
                leadingIcon: const Icon(AppIcons.add01),
                onPressed: () => _editReplyExample(),
              )
            : null,
        child: _examples.isEmpty
            ? AdminEmptyState(
                icon: AppIcons.comment01,
                message: S.aiKnowledgeNoExamples,
                hint: S.aiKnowledgeExamplesHint,
                action: widget.canManage
                    ? CustomBtn(
                        text: S.aiKnowledgeAddExample,
                        leadingIcon: const Icon(AppIcons.add01),
                        onPressed: () => _editReplyExample(),
                      )
                    : null,
              )
            : Column(
                children: [
                  for (final example in _examples)
                    _ReplyExampleTile(
                      example: example,
                      canManage: widget.canManage,
                      onEdit: () => _editReplyExample(example),
                      onDelete: () => _deleteReplyExample(example),
                    ),
                ],
              ),
      ),
    ],
  );

  Widget _secretField() => TextField(
    controller: _apiKey,
    obscureText: true,
    enabled: widget.canManage,
    decoration: InputDecoration(
      labelText: S.aiKnowledgeApiKey,
      hintText: _hasKey ? S.aiKnowledgeKeyReplaceHint : S.aiKnowledgeApiKeyHint,
      suffixIcon: const Icon(AppIcons.password),
      border: const OutlineInputBorder(),
    ),
    autocorrect: false,
    enableSuggestions: false,
  );

  Widget _textField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        enabled: widget.canManage,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _textArea(
    TextEditingController controller,
    String label, {
    required int minLines,
  }) => TextField(
    controller: controller,
    enabled: widget.canManage,
    minLines: minLines,
    maxLines: minLines + 3,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: values.contains(value) ? value : values.first,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(_optionLabel(item))),
    ],
    onChanged: widget.canManage
        ? (next) {
            if (next != null) onChanged(next);
          }
        : null,
  );

  Widget _fieldRow(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 620;
      return Flex(
        direction: wide ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0)
              SizedBox(
                width: wide ? AppSpacing.md : 0,
                height: wide ? 0 : AppSpacing.md,
              ),
            if (wide) Expanded(child: fields[i]) else fields[i],
          ],
        ],
      );
    },
  );

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) => AdminSectionCard(title: title, subtitle: subtitle, child: child);

  String _optionLabel(String value) => switch (value) {
    'gemini' => S.aiProviderGemini,
    'groq' => S.aiProviderGroq,
    'openrouter' => S.aiProviderOpenRouter,
    'openai' => S.aiProviderOpenAI,
    'custom' => S.aiProviderCustom,
    'friendly' => S.aiToneFriendly,
    'professional' => S.aiToneProfessional,
    'casual' => S.aiToneCasual,
    _ => value,
  };

  String _providerLabel(String value) => _optionLabel(value);

  String _text(dynamic value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  int _integer(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(adminErrorMessage(error))));
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> article;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ar = AppLocale.instance.isArabic;
    final title =
        _value(article[ar ? 'title_ar' : 'title_en']) ??
        _value(article['title_ar']) ??
        '';
    final body = _value(article[ar ? 'body_ar' : 'body_en']) ?? '';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: adminMutedColor(theme)),
                ),
              ],
            ),
          ),
          if (canManage) ...[
            IconButton(
              tooltip: S.edit,
              onPressed: onEdit,
              icon: const Icon(AppIcons.edit01),
            ),
            IconButton(
              tooltip: S.delete,
              onPressed: onDelete,
              icon: const Icon(AppIcons.delete02),
            ),
          ],
        ],
      ),
    );
  }

  static String? _value(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _ReplyExampleTile extends StatelessWidget {
  const _ReplyExampleTile({
    required this.example,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> example;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final variants = example['response_variants'];
    final first =
        variants is List && variants.isNotEmpty && variants.first is Map
        ? Map<String, dynamic>.from(variants.first as Map)
        : const <String, dynamic>{};
    final reply = first['text_ar'] is String ? first['text_ar'] as String : '';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _safeText(example['intent']),
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _safeText(example['user_message_ar']),
                  style: TextStyle(color: adminMutedColor(theme)),
                ),
                if (reply.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(reply, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (canManage) ...[
            IconButton(
              tooltip: S.edit,
              onPressed: onEdit,
              icon: const Icon(AppIcons.edit01),
            ),
            IconButton(
              tooltip: S.delete,
              onPressed: onDelete,
              icon: const Icon(AppIcons.delete02),
            ),
          ],
        ],
      ),
    );
  }

  String _safeText(dynamic value) => value is String ? value : '';
}

class _KnowledgeArticleDialog extends StatefulWidget {
  const _KnowledgeArticleDialog({this.article});
  final Map<String, dynamic>? article;

  @override
  State<_KnowledgeArticleDialog> createState() =>
      _KnowledgeArticleDialogState();
}

class _KnowledgeArticleDialogState extends State<_KnowledgeArticleDialog> {
  final _slug = TextEditingController();
  final _category = TextEditingController();
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _bodyAr = TextEditingController();
  final _bodyEn = TextEditingController();
  final _keywords = TextEditingController();
  bool _active = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final row = widget.article;
    _slug.text = _get(row, 'slug');
    _category.text = _get(row, 'category', 'faq');
    _titleAr.text = _get(row, 'title_ar');
    _titleEn.text = _get(row, 'title_en');
    _bodyAr.text = _get(row, 'body_ar');
    _bodyEn.text = _get(row, 'body_en');
    _keywords.text = (row?['keywords'] is List)
        ? (row!['keywords'] as List).join(', ')
        : '';
    _active = row?['is_active'] != false;
  }

  @override
  void dispose() {
    for (final controller in [
      _slug,
      _category,
      _titleAr,
      _titleEn,
      _bodyAr,
      _bodyEn,
      _keywords,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.article == null
          ? S.aiKnowledgeAddArticle
          : S.aiKnowledgeEditArticle,
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (_error != null) _InlineError(message: _error!),
            _dialogField(_slug, S.aiKnowledgeSlug),
            const SizedBox(height: AppSpacing.md),
            _dialogField(_category, S.aiKnowledgeCategory),
            const SizedBox(height: AppSpacing.md),
            _dialogField(_titleAr, S.aiKnowledgeTitleAr),
            const SizedBox(height: AppSpacing.md),
            _dialogField(_titleEn, S.aiKnowledgeTitleEn),
            const SizedBox(height: AppSpacing.md),
            _dialogField(_bodyAr, S.aiKnowledgeBodyAr, lines: 4),
            const SizedBox(height: AppSpacing.md),
            _dialogField(_bodyEn, S.aiKnowledgeBodyEn, lines: 4),
            const SizedBox(height: AppSpacing.md),
            _dialogField(_keywords, S.aiKnowledgeKeywords),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              title: Text(S.aiKnowledgeArticleActive),
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(S.cancel),
      ),
      FilledButton(onPressed: _save, child: Text(S.save)),
    ],
  );

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) => TextField(
    controller: controller,
    minLines: lines,
    maxLines: lines == 1 ? 1 : lines + 2,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  void _save() {
    final requiredFields = [_slug, _titleAr, _titleEn, _bodyAr, _bodyEn];
    if (requiredFields.any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = S.aiKnowledgeRequiredFields);
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      if (widget.article?['id'] != null) 'id': widget.article!['id'],
      'slug': _slug.text.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9_]+'),
        '_',
      ),
      'category': _category.text.trim().isEmpty ? 'faq' : _category.text.trim(),
      'title_ar': _titleAr.text.trim(),
      'title_en': _titleEn.text.trim(),
      'body_ar': _bodyAr.text.trim(),
      'body_en': _bodyEn.text.trim(),
      'keywords': _keywords.text
          .split(',')
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty)
          .toList(),
      'is_active': _active,
    });
  }

  String _get(Map<String, dynamic>? row, String key, [String fallback = '']) {
    final value = row?[key];
    return value is String ? value : fallback;
  }
}

class _ReplyExampleDialog extends StatefulWidget {
  const _ReplyExampleDialog({this.example});
  final Map<String, dynamic>? example;

  @override
  State<_ReplyExampleDialog> createState() => _ReplyExampleDialogState();
}

class _ReplyExampleDialogState extends State<_ReplyExampleDialog> {
  final _category = TextEditingController(text: 'general');
  final _intent = TextEditingController();
  final _questionAr = TextEditingController();
  final _questionEn = TextEditingController();
  final _replyAr = TextEditingController();
  final _replyEn = TextEditingController();
  String _tone = 'friendly';
  bool _pinned = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final row = widget.example;
    _category.text = _value(row?['category'], 'general');
    _intent.text = _value(row?['intent']);
    _questionAr.text = _value(row?['user_message_ar']);
    _questionEn.text = _value(row?['user_message_en']);
    final variants = row?['response_variants'];
    final first =
        variants is List && variants.isNotEmpty && variants.first is Map
        ? Map<String, dynamic>.from(variants.first as Map)
        : const <String, dynamic>{};
    _replyAr.text = _value(first['text_ar']);
    _replyEn.text = _value(first['text_en']);
    _tone = _value(row?['tone'], 'friendly');
    _pinned = row?['is_pinned'] == true;
  }

  @override
  void dispose() {
    for (final controller in [
      _category,
      _intent,
      _questionAr,
      _questionEn,
      _replyAr,
      _replyEn,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.example == null
          ? S.aiKnowledgeAddExample
          : S.aiKnowledgeEditExample,
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (_error != null) _InlineError(message: _error!),
            _field(_category, S.aiKnowledgeCategory),
            const SizedBox(height: AppSpacing.md),
            _field(_intent, S.aiKnowledgeIntent),
            const SizedBox(height: AppSpacing.md),
            _field(_questionAr, S.aiKnowledgeQuestionAr, lines: 2),
            const SizedBox(height: AppSpacing.md),
            _field(_questionEn, S.aiKnowledgeQuestionEn, lines: 2),
            const SizedBox(height: AppSpacing.md),
            _field(_replyAr, S.aiKnowledgeExampleReplyAr, lines: 3),
            const SizedBox(height: AppSpacing.md),
            _field(_replyEn, S.aiKnowledgeExampleReplyEn, lines: 3),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _tone,
              decoration: InputDecoration(
                labelText: S.aiKnowledgeTone,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final value in const [
                  'friendly',
                  'professional',
                  'casual',
                ])
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _tone = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pinned,
              title: Text(S.aiKnowledgePinExample),
              onChanged: (value) => setState(() => _pinned = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(S.cancel),
      ),
      FilledButton(onPressed: _save, child: Text(S.save)),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) => TextField(
    controller: controller,
    minLines: lines,
    maxLines: lines == 1 ? 1 : lines + 2,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  void _save() {
    if ([_intent, _questionAr, _replyAr].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = S.aiKnowledgeRequiredFields);
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      if (widget.example?['id'] != null) 'id': widget.example!['id'],
      'category': _category.text.trim().isEmpty
          ? 'general'
          : _category.text.trim(),
      'intent': _intent.text.trim(),
      'user_message_ar': _questionAr.text.trim(),
      'user_message_en': _questionEn.text.trim(),
      'response_ar': _replyAr.text.trim(),
      'response_en': _replyEn.text.trim(),
      'tone': _tone,
      'is_pinned': _pinned,
    });
  }

  String _value(dynamic raw, [String fallback = '']) =>
      raw is String ? raw : fallback;
}
