import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/app_simulator/presentation/pages/app_simulator_page.dart';
import 'package:admin_app/features/splash_management/data/splash_management_repository.dart';
import 'package:admin_app/features/splash_management/domain/splash_settings.dart';
import 'package:admin_app/features/splash_management/presentation/manager/splash_management_cubit.dart';
import 'package:admin_app/features/splash_management/presentation/manager/splash_management_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class SplashManagementPage extends StatefulWidget {
  const SplashManagementPage({
    super.key,
    this.repository,
    this.cubit,
    this.canPublish = false,
  });

  final SplashManagementRepository? repository;
  final SplashManagementCubit? cubit;
  final bool canPublish;

  @override
  State<SplashManagementPage> createState() => _SplashManagementPageState();
}

class _SplashManagementPageState extends State<SplashManagementPage> {
  late final SplashManagementCubit _cubit;
  late final bool _ownsCubit;
  final _imageUrl = TextEditingController();
  final _textAr = TextEditingController();
  final _textEn = TextEditingController();
  final _textColor = TextEditingController();
  final _backgroundColor = TextEditingController();
  final _imageWidth = TextEditingController();
  final _imageHeight = TextEditingController();
  final _textSize = TextEditingController();
  final _imageGap = TextEditingController();
  final _duration = TextEditingController();
  final _animationDuration = TextEditingController();

  SplashManagementSnapshot? _lastSyncedSnapshot;

  bool get _isArabic => AppLocale.instance.isArabic;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit =
        widget.cubit ?? SplashManagementCubit(repository: widget.repository);
    _cubit.load();
  }

  @override
  void dispose() {
    for (final controller in [
      _imageUrl,
      _textAr,
      _textEn,
      _textColor,
      _backgroundColor,
      _imageWidth,
      _imageHeight,
      _textSize,
      _imageGap,
      _duration,
      _animationDuration,
    ]) {
      controller.dispose();
    }
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  String _t(String ar, String en) => S.splashCopy(ar, en);

  Future<void> _load() async {
    await _cubit.load();
  }

  void _syncControllers(SplashSettings value) {
    _imageUrl.text = value.imageUrl;
    _textAr.text = value.textAr;
    _textEn.text = value.textEn;
    _textColor.text = value.textColor;
    _backgroundColor.text = value.backgroundColor;
    _imageWidth.text = value.imageWidth?.toStringAsFixed(0) ?? '';
    _imageHeight.text = value.imageHeight?.toStringAsFixed(0) ?? '';
    _textSize.text = value.textSize.toStringAsFixed(0);
    _imageGap.text = value.imageGap.toStringAsFixed(0);
    _duration.text = value.durationMs.toString();
    _animationDuration.text = value.animationDurationMs.toString();
  }

  void _update(SplashSettings Function(SplashSettings) change) =>
      _cubit.updateSettings(change(_cubit.state.settings));

  bool _isValid() {
    final current = _cubit.state.settings;
    if (!_validNumber(_textSize, 8, 48) ||
        !_validNumber(_imageGap, 0, 100) ||
        !_validNumber(_duration, 0, 30000) ||
        !_validNumber(_animationDuration, 0, 5000) ||
        !_validOptionalNumber(_imageWidth, 40, 600) ||
        !_validOptionalNumber(_imageHeight, 40, 700)) {
      _cubit.showValidationError('invalid_numeric_value');
      return false;
    }
    final candidate = current.copyWith(
      imageUrl: _imageUrl.text.trim(),
      textAr: _textAr.text,
      textEn: _textEn.text,
      textColor: _textColor.text.trim(),
      backgroundColor: _backgroundColor.text.trim(),
      imageWidth: double.tryParse(_imageWidth.text.trim()),
      clearImageWidth: _imageWidth.text.trim().isEmpty,
      imageHeight: double.tryParse(_imageHeight.text.trim()),
      clearImageHeight: _imageHeight.text.trim().isEmpty,
      textSize: double.parse(_textSize.text.trim()),
      imageGap: double.parse(_imageGap.text.trim()),
      durationMs: int.parse(_duration.text.trim()),
      animationDurationMs: int.parse(_animationDuration.text.trim()),
    );
    _cubit.updateSettings(candidate);
    final issue = candidate.validationIssue;
    if (issue != null) {
      _cubit.showValidationError(issue);
      return false;
    }
    return true;
  }

  bool _validNumber(TextEditingController controller, num min, num max) {
    final value = num.tryParse(controller.text.trim());
    return value != null && value >= min && value <= max;
  }

  bool _validOptionalNumber(
    TextEditingController controller,
    num min,
    num max,
  ) {
    if (controller.text.trim().isEmpty) return true;
    return _validNumber(controller, min, max);
  }

  void _saveDraft() {
    if (_isValid()) _cubit.saveDraft();
  }

  void _publish() {
    if (widget.canPublish && _isValid()) _cubit.publish();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SplashManagementCubit>.value(
      value: _cubit,
      child: BlocConsumer<SplashManagementCubit, SplashManagementState>(
        listener: (context, state) {
          if (state.snapshot != null && state.snapshot != _lastSyncedSnapshot) {
            _lastSyncedSnapshot = state.snapshot;
            _syncControllers(state.settings);
          }
        },
        builder: (context, state) {
          if (state.isLoading) return const AdminLoadingView();
          if (state.hasLoadError) {
            return AdminFailureView(
              message: _errorMessage(state.error),
              onRetry: _load,
            );
          }
          final width = MediaQuery.sizeOf(context).width;
          return SingleChildScrollView(
            child: AdminPageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _pageHeader(state),
                  if (state.error != null)
                    _message(_errorMessage(state.error)!, isError: true),
                  if (state.notice != null)
                    _message(_noticeMessage(state.notice!)),
                  if (width >= 1100)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _settingsPanel(state)),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(flex: 5, child: _previewPanel(state)),
                      ],
                    )
                  else ...[
                    _previewPanel(state),
                    const SizedBox(height: AppSpacing.lg),
                    _settingsPanel(state),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _errorMessage(String? code) {
    if (code == null) return null;
    return switch (code) {
      'invalid_color' => _t(
        'صيغة اللون غير صحيحة. استخدم #RRGGBB.',
        'Invalid color. Use #RRGGBB.',
      ),
      'invalid_image_url' => _t(
        'رابط الصورة يجب أن يبدأ بـ http أو https.',
        'The image URL must start with http or https.',
      ),
      'invalid_numeric_value' => _t(
        'راجع القيم الرقمية وحدودها.',
        'Check numeric values and their allowed ranges.',
      ),
      'published_readback_mismatch' => _t(
        'تعذر تأكيد قراءة النسخة المنشورة من Supabase.',
        'Could not verify the published document in Supabase.',
      ),
      _ => code,
    };
  }

  String _noticeMessage(String notice) {
    if (notice == 'saved') {
      return _t('تم حفظ المسودة في Supabase.', 'Draft saved to Supabase.');
    }
    if (notice.startsWith('published:')) {
      final version = notice.substring('published:'.length);
      return _t(
        'تم نشر النسخة $version والتحقق من قراءتها من Supabase.',
        'Version $version was published and read back from Supabase.',
      );
    }
    return notice;
  }

  Widget _pageHeader(SplashManagementState state) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('إدارة شاشة البداية', 'Splash screen management'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _t(
                'تحكم مستقل في شاشة البداية للعميل. التعديلات لا تصل للعميل قبل النشر.',
                'Manage the customer splash screen. Draft changes stay private until published.',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: state.isBusy ? null : _saveDraft,
              icon: const Icon(AppIcons.note01),
              label: Text(_t('حفظ المسودة', 'Save draft')),
            ),
            FilledButton.icon(
              onPressed: state.isBusy || !widget.canPublish ? null : _publish,
              icon: state.isBusy
                  ? const SizedBox(
                      width: AppSizes.px16,
                      height: AppSizes.px16,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.xxs,
                      ),
                    )
                  : const Icon(AppIcons.play),
              label: Text(_t('نشر للعميل', 'Publish to customers')),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _settingsPanel(SplashManagementState state) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(AppIcons.tune, _t('خصائص الشاشة', 'Screen properties')),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: state.settings.enabled,
            title: Text(_t('عرض شاشة البداية', 'Show splash screen')),
            onChanged: state.isBusy
                ? null
                : (v) => _update((s) => s.copyWith(enabled: v)),
          ),
          const Divider(height: 24),
          _sectionTitle(
            AppIcons.image01,
            _t('الشعار والصورة', 'Logo and image'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: state.settings.imageVisible,
            title: Text(_t('عرض الشعار', 'Show logo')),
            onChanged: state.isBusy
                ? null
                : (v) => _update((s) => s.copyWith(imageVisible: v)),
          ),
          _textField(
            _imageUrl,
            _t('رابط صورة الشعار', 'Logo image URL'),
            onChanged: (v) => _update((s) => s.copyWith(imageUrl: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  _imageWidth,
                  _t('العرض (40–600)', 'Width (40–600)'),
                  min: 40,
                  max: 600,
                  onChanged: (v) => _update(
                    (s) => s.copyWith(
                      imageWidth: v == null ? null : double.tryParse(v),
                      clearImageWidth: v == null || v.isEmpty,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  _imageHeight,
                  _t('الارتفاع (40–700)', 'Height (40–700)'),
                  min: 40,
                  max: 700,
                  onChanged: (v) => _update(
                    (s) => s.copyWith(
                      imageHeight: v == null ? null : double.tryParse(v),
                      clearImageHeight: v == null || v.isEmpty,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown<String>(
            _t('ملاءمة الصورة', 'Image fit'),
            state.settings.imageFit,
            const [
              'contain',
              'cover',
              'fill',
              'fitWidth',
              'fitHeight',
              'scaleDown',
            ],
            (v) => _update((s) => s.copyWith(imageFit: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown<String>(
            _t('محاذاة الصورة', 'Image alignment'),
            state.settings.imageAlignment,
            const [
              'topLeft',
              'topCenter',
              'topRight',
              'centerLeft',
              'center',
              'centerRight',
              'bottomLeft',
              'bottomCenter',
              'bottomRight',
            ],
            (v) => _update((s) => s.copyWith(imageAlignment: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            _imageGap,
            _t('المسافة بين الصورة والنص (0–100)', 'Image to text gap (0–100)'),
            min: 0,
            max: 100,
            onChanged: (v) => _update(
              (s) => s.copyWith(imageGap: double.tryParse(v ?? '') ?? 16),
            ),
          ),
          const Divider(height: 32),
          _sectionTitle(
            AppIcons.note01,
            _t('النص والألوان', 'Text and colors'),
          ),
          _textField(
            _textAr,
            _t('النص بالعربية', 'Arabic text'),
            maxLines: 2,
            onChanged: (v) => _update((s) => s.copyWith(textAr: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _textField(
            _textEn,
            _t('النص بالإنجليزية', 'English text'),
            maxLines: 2,
            onChanged: (v) => _update((s) => s.copyWith(textEn: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _textField(
                  _textColor,
                  _t('لون النص (#RRGGBB)', 'Text color (#RRGGBB)'),
                  onChanged: (v) => _update((s) => s.copyWith(textColor: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  _textSize,
                  _t('حجم النص (8–48)', 'Text size (8–48)'),
                  min: 8,
                  max: 48,
                  onChanged: (v) => _update(
                    (s) => s.copyWith(textSize: double.tryParse(v ?? '') ?? 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _textField(
            _backgroundColor,
            _t('لون الخلفية (#RRGGBB)', 'Background color (#RRGGBB)'),
            onChanged: (v) => _update((s) => s.copyWith(backgroundColor: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown<String>(
            _t('محاذاة النص', 'Text alignment'),
            state.settings.textAlignment,
            const ['start', 'center', 'end'],
            (v) => _update((s) => s.copyWith(textAlignment: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown<String>(
            _t('الموضع الرأسي للمحتوى', 'Vertical content position'),
            state.settings.verticalAlignment,
            const ['top', 'center', 'bottom'],
            (v) => _update((s) => s.copyWith(verticalAlignment: v)),
          ),
          const Divider(height: 32),
          _sectionTitle(
            AppIcons.time01,
            _t('المدة والحركة', 'Duration and animation'),
          ),
          _numberField(
            _duration,
            _t(
              'مدة شاشة البداية (0–30000 مللي ثانية)',
              'Splash duration (0–30000 ms)',
            ),
            min: 0,
            max: 30000,
            onChanged: (v) => _update(
              (s) => s.copyWith(durationMs: int.tryParse(v ?? '') ?? 1000),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _dropdown<String>(
            _t('نوع الحركة', 'Animation'),
            state.settings.animation,
            const ['none', 'fade', 'fadeScale'],
            (v) => _update((s) => s.copyWith(animation: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            _animationDuration,
            _t(
              'مدة الحركة (0–5000 مللي ثانية)',
              'Animation duration (0–5000 ms)',
            ),
            min: 0,
            max: 5000,
            onChanged: (v) => _update(
              (s) =>
                  s.copyWith(animationDurationMs: int.tryParse(v ?? '') ?? 300),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.snapshot != null)
            Text(
              state.snapshot!.hasDraft
                  ? _t(
                      'توجد مسودة محفوظة؛ معاينة الشاشة تعرض آخر تعديلاتك.',
                      'A saved draft exists; the preview shows your latest edits.',
                    )
                  : _t(
                      'لا توجد مسودة؛ المعاينة تبدأ من الإعدادات المنشورة أو القيم الافتراضية.',
                      'No draft exists; preview starts from published settings or defaults.',
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
  );

  Widget _previewPanel(SplashManagementState state) => Card(
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: 720,
      child: AppSimulatorPage(
        designDocument: SplashSettings.writeToDocument(
          state.snapshot?.document,
          state.settings,
        ),
        initialPageId: 'splash',
      ),
    ),
  );
  Widget _sectionTitle(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: AppSizes.px20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) => TextField(
    controller: controller,
    enabled: !_cubit.state.isBusy,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged,
  );

  Widget _numberField(
    TextEditingController controller,
    String label, {
    required int min,
    required int max,
    required ValueChanged<String?> onChanged,
  }) => TextField(
    controller: controller,
    enabled: !_cubit.state.isBusy,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onChanged: (raw) {
      final value = double.tryParse(raw);
      if (raw.isEmpty) {
        onChanged(null);
      } else if (value != null && value >= min && value <= max) {
        onChanged(raw);
      }
    },
  );

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T> onChanged,
  ) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem<T>(
          value: item,
          child: Text(_optionLabel(item.toString())),
        ),
    ],
    onChanged: _cubit.state.isBusy
        ? null
        : (next) {
            if (next != null) onChanged(next);
          },
  );

  String _optionLabel(String value) => _isArabic
      ? switch (value) {
          'contain' => 'احتواء',
          'cover' => 'تغطية',
          'fill' => 'ملء',
          'fitWidth' => 'ملاءمة العرض',
          'fitHeight' => 'ملاءمة الارتفاع',
          'scaleDown' => 'تصغير عند الحاجة',
          'topLeft' => 'أعلى اليسار',
          'topCenter' => 'أعلى الوسط',
          'topRight' => 'أعلى اليمين',
          'centerLeft' => 'الوسط يسار',
          'center' => 'الوسط',
          'centerRight' => 'الوسط يمين',
          'bottomLeft' => 'أسفل اليسار',
          'bottomCenter' => 'أسفل الوسط',
          'bottomRight' => 'أسفل اليمين',
          'start' => 'بداية السطر',
          'end' => 'نهاية السطر',
          'top' => 'أعلى',
          'bottom' => 'أسفل',
          'none' => 'بدون',
          'fade' => 'تلاشي',
          'fadeScale' => 'تلاشي وتكبير',
          _ => value,
        }
      : switch (value) {
          'fadeScale' => 'Fade and scale',
          _ => value,
        };

  Widget _message(String message, {bool isError = false}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message),
  );
}
