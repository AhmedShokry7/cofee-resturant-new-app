import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/visual_editor/data/design_image_upload.dart';

class EmailDesignPage extends StatefulWidget {
  const EmailDesignPage({super.key});
  @override
  State<EmailDesignPage> createState() => _EmailDesignPageState();
}

class _EmailDesignPageState extends State<EmailDesignPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _loading = true, _saving = false, _uploading = false;
  String? _error;
  String? _activeField;
  static const _defaults = <String, String>{
    'appNameAr': 'غيم وسحب', 'appNameEn': 'Ghem & Sohob', 'logoUrl': '',
    'logoWidth': '160', 'cardRadius': '18', 'layoutStyle': 'centered', 'showLogo': 'true',
    'primaryColor': '#078A75', 'backgroundColor': '#F3F6F5', 'surfaceColor': '#FFFFFF',
    'textColor': '#172522', 'buttonColor': '#078A75', 'otpCodeColor': '#078A75',
    'footerAr': 'هذه رسالة آلية من {{app_name}}.', 'footerEn': 'This is an automated message from {{app_name}}.',
    'signupSubjectAr': 'تأكيد بريدك الإلكتروني | {{app_name}}', 'signupSubjectEn': '{{app_name}} | Confirm your email',
    'signupTitleAr': 'تأكيد بريدك الإلكتروني', 'signupTitleEn': 'Confirm your email',
    'signupBodyAr': 'مرحبًا {{customer_name}}، أدخل رمز التحقق التالي لإكمال إنشاء حسابك.',
    'signupBodyEn': 'Hello {{customer_name}}, enter the verification code below to finish creating your account.',
    'otpLabelAr': 'رمز التحقق', 'otpLabelEn': 'Verification code',
  };
  SupabaseClient get _db => SupabaseService.client;
  bool get _ar => AppLocale.instance.isArabic;
  String _tr(String ar, String en) => _ar ? ar : en;
  TextEditingController _controller(String key) => _fields.putIfAbsent(key, () {
    final c = TextEditingController(text: _defaults[key] ?? '');
    c.addListener(() { if (mounted) setState(() {}); });
    return c;
  });

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final c in _fields.values) { c.dispose(); } super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _db.rpc('admin_email_design_get');
      final config = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      for (final entry in _defaults.entries) { _controller(entry.key).text = '${config[entry.key] ?? entry.value}'; }
    } catch (e) { _error = '${_tr('تعذر تحميل الإعدادات: ', 'Could not load settings: ')}$e'; }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final config = <String, String>{for (final key in _defaults.keys) key: _controller(key).text.trim()};
      await _db.rpc('admin_email_design_save', params: {'p_config': config});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr('تم حفظ تصميم البريد الإلكتروني.', 'Email design saved.'))));
    } catch (e) { if (mounted) setState(() => _error = '${_tr('تعذر الحفظ: ', 'Could not save: ')}$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _uploadLogo() async {
    setState(() => _uploading = true);
    try {
      final url = await DesignImageUpload.pickAndUpload();
      if (url != null && mounted) { _controller('logoUrl').text = url; await _save(); }
    } catch (e) { if (mounted) setState(() => _error = '${_tr('تعذر رفع الصورة: ', 'Image upload failed: ')}$e'); }
    finally { if (mounted) setState(() => _uploading = false); }
  }

  Widget _field(String key, String label, {int lines = 1, String? hint, bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _controller(key), maxLines: lines, textDirection: _isArabicField(key) ? TextDirection.rtl : TextDirection.ltr,
      onTap: () => _activeField = key,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), alignLabelWithHint: lines > 1),
      validator: (value) {
        final text = (value ?? '').trim();
        if (required && text.isEmpty) return _tr('هذا الحقل مطلوب', 'This field is required');
        if (key.endsWith('Color') && !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)) return _tr('اكتب لونًا بصيغة #078A75', 'Enter a color like #078A75');
        if (key == 'logoWidth' && (int.tryParse(text) == null || int.parse(text) < 48 || int.parse(text) > 320)) return _tr('العرض من 48 إلى 320 بكسل', 'Width must be 48–320 px');
        if (key == 'cardRadius' && (int.tryParse(text) == null || int.parse(text) < 0 || int.parse(text) > 32)) return _tr('نصف القطر من 0 إلى 32', 'Radius must be 0–32');
        return null;
      },
    ),
  );
  bool _isArabicField(String key) => key.endsWith('Ar') || key == 'appNameAr';

  Widget _section(String title, String subtitle, List<Widget> children, {IconData icon = Icons.tune}) => Card(
    child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)]))]),
      const SizedBox(height: 20), ...children,
    ])),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppLocale.instance,
    builder: (context, _) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Directionality(textDirection: AppLocale.instance.textDirection, child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: Form(
          key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tr('تصميم البريد الإلكتروني', 'Email design'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5), Text(_tr('صمّم رسائل التحقق والإشعارات بهوية تطبيقك وعاينها قبل الحفظ.', 'Customize verification and notification emails with your app identity and preview them before saving.')),
            ])), IconButton(onPressed: _loading ? null : _load, tooltip: _tr('إعادة تحميل', 'Reload'), icon: const Icon(Icons.refresh))]),
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, box) {
              final editor = Column(children: [
                _section(_tr('هوية الرسالة', 'Email identity'), _tr('اسم التطبيق والشعار المستخدمان في رسائل العملاء.', 'App name and logo shown in customer emails.'), [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _field('\u{61}\u{70}\u{70}\u{4e}\u{61}\u{6d}\u{65}\u{41}\u{72}', _tr('\u{627}\u{633}\u{645}\u{20}\u{627}\u{644}\u{62a}\u{637}\u{628}\u{64a}\u{642}\u{20}\u{628}\u{627}\u{644}\u{639}\u{631}\u{628}\u{64a}\u{629}', '\u{41}\u{70}\u{70}\u{20}\u{6e}\u{61}\u{6d}\u{65}\u{20}\u{69}\u{6e}\u{20}\u{41}\u{72}\u{61}\u{62}\u{69}\u{63}'), required: true)), const SizedBox(width: 12), Expanded(child: _field('\u{61}\u{70}\u{70}\u{4e}\u{61}\u{6d}\u{65}\u{45}\u{6e}', _tr('\u{627}\u{633}\u{645}\u{20}\u{627}\u{644}\u{62a}\u{637}\u{628}\u{64a}\u{642}\u{20}\u{628}\u{627}\u{644}\u{625}\u{646}\u{62c}\u{644}\u{64a}\u{632}\u{64a}\u{629}', '\u{41}\u{70}\u{70}\u{20}\u{6e}\u{61}\u{6d}\u{65}\u{20}\u{69}\u{6e}\u{20}\u{45}\u{6e}\u{67}\u{6c}\u{69}\u{73}\u{68}'), required: true))]),
                  _logoSource(),
                  Row(children: [Expanded(child: _field('logoWidth', _tr('عرض الشعار (بكسل)', 'Logo width (px)'))), const SizedBox(width: 12), Expanded(child: _field('cardRadius', _tr('استدارة البطاقة', 'Card corner radius')))]),
                  DropdownButtonFormField<String>(value: _controller('layoutStyle').text, decoration: InputDecoration(labelText: _tr('تخطيط الرسالة', 'Email layout'), border: const OutlineInputBorder()), items: [DropdownMenuItem(value: 'centered', child: Text(_tr('مركزي', 'Centered'))), DropdownMenuItem(value: 'simple', child: Text(_tr('بسيط', 'Simple')))], onChanged: (v) { if (v != null) _controller('layoutStyle').text = v; }),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(_tr('إظهار الشعار', 'Show logo')), value: _controller('showLogo').text == 'true', onChanged: (v) => _controller('showLogo').text = '$v'),
                ], icon: Icons.storefront),
                const SizedBox(height: 16),
                _section(_tr('الألوان والتذييل', 'Colors and footer'), _tr('اضبط ألوان الخلفية والبطاقة والنص والرمز والزر.', 'Set background, card, text, code, and button colors.'), [
                  Wrap(spacing: 12, runSpacing: 2, children: [for (final item in <(String,String)>[('primaryColor', _tr('اللون الأساسي', 'Primary color')), ('backgroundColor', _tr('الخلفية', 'Background')), ('surfaceColor', _tr('البطاقة', 'Card')), ('textColor', _tr('النص', 'Text')), ('buttonColor', _tr('الزر', 'Button')), ('otpCodeColor', _tr('رمز التحقق', 'OTP code'))]) SizedBox(width: 180, child: _field(item.$1, item.$2))]),
                  _field('\u{66}\u{6f}\u{6f}\u{74}\u{65}\u{72}\u{41}\u{72}', _tr('\u{627}\u{644}\u{62a}\u{630}\u{64a}\u{64a}\u{644}\u{20}\u{628}\u{627}\u{644}\u{639}\u{631}\u{628}\u{64a}\u{629}', '\u{46}\u{6f}\u{6f}\u{74}\u{65}\u{72}\u{20}\u{69}\u{6e}\u{20}\u{41}\u{72}\u{61}\u{62}\u{69}\u{63}'), lines: 2), _field('\u{66}\u{6f}\u{6f}\u{74}\u{65}\u{72}\u{45}\u{6e}', _tr('\u{627}\u{644}\u{62a}\u{630}\u{64a}\u{64a}\u{644}\u{20}\u{628}\u{627}\u{644}\u{625}\u{646}\u{62c}\u{644}\u{64a}\u{632}\u{64a}\u{629}', '\u{46}\u{6f}\u{6f}\u{74}\u{65}\u{72}\u{20}\u{69}\u{6e}\u{20}\u{45}\u{6e}\u{67}\u{6c}\u{69}\u{73}\u{68}'), lines: 2),
                ], icon: Icons.palette_outlined),
                const SizedBox(height: 16),
                _section(_tr('رسالة رمز التحقق عند التسجيل', 'Signup verification email'), _tr('حرّر العنوان والمحتوى لكل لغة. المتغيرات تُستبدل تلقائيًا عند الإرسال.', 'Edit the subject and message in both languages. Variables are replaced automatically.'), [
                  _variables(),
                  _field('\u{73}\u{69}\u{67}\u{6e}\u{75}\u{70}\u{53}\u{75}\u{62}\u{6a}\u{65}\u{63}\u{74}\u{41}\u{72}', _tr('\u{639}\u{646}\u{648}\u{627}\u{646}\u{20}\u{627}\u{644}\u{631}\u{633}\u{627}\u{644}\u{629}\u{20}\u{628}\u{627}\u{644}\u{639}\u{631}\u{628}\u{64a}\u{629}', '\u{53}\u{75}\u{62}\u{6a}\u{65}\u{63}\u{74}\u{20}\u{69}\u{6e}\u{20}\u{41}\u{72}\u{61}\u{62}\u{69}\u{63}')), _field('\u{73}\u{69}\u{67}\u{6e}\u{75}\u{70}\u{54}\u{69}\u{74}\u{6c}\u{65}\u{41}\u{72}', _tr('\u{639}\u{646}\u{648}\u{627}\u{646}\u{20}\u{627}\u{644}\u{645}\u{62d}\u{62a}\u{648}\u{649}\u{20}\u{628}\u{627}\u{644}\u{639}\u{631}\u{628}\u{64a}\u{629}', '\u{48}\u{65}\u{61}\u{64}\u{69}\u{6e}\u{67}\u{20}\u{69}\u{6e}\u{20}\u{41}\u{72}\u{61}\u{62}\u{69}\u{63}')), _field('\u{73}\u{69}\u{67}\u{6e}\u{75}\u{70}\u{42}\u{6f}\u{64}\u{79}\u{41}\u{72}', _tr('\u{646}\u{635}\u{20}\u{627}\u{644}\u{631}\u{633}\u{627}\u{644}\u{629}\u{20}\u{628}\u{627}\u{644}\u{639}\u{631}\u{628}\u{64a}\u{629}', '\u{4d}\u{65}\u{73}\u{73}\u{61}\u{67}\u{65}\u{20}\u{69}\u{6e}\u{20}\u{41}\u{72}\u{61}\u{62}\u{69}\u{63}'), lines: 3), _field('\u{6f}\u{74}\u{70}\u{4c}\u{61}\u{62}\u{65}\u{6c}\u{41}\u{72}', _tr('\u{62a}\u{633}\u{645}\u{64a}\u{629}\u{20}\u{627}\u{644}\u{631}\u{645}\u{632}\u{20}\u{628}\u{627}\u{644}\u{639}\u{631}\u{628}\u{64a}\u{629}', '\u{43}\u{6f}\u{64}\u{65}\u{20}\u{6c}\u{61}\u{62}\u{65}\u{6c}\u{20}\u{69}\u{6e}\u{20}\u{41}\u{72}\u{61}\u{62}\u{69}\u{63}')),
                  const Divider(height: 24),
                  _field('\u{73}\u{69}\u{67}\u{6e}\u{75}\u{70}\u{53}\u{75}\u{62}\u{6a}\u{65}\u{63}\u{74}\u{45}\u{6e}', _tr('\u{639}\u{646}\u{648}\u{627}\u{646}\u{20}\u{627}\u{644}\u{631}\u{633}\u{627}\u{644}\u{629}\u{20}\u{628}\u{627}\u{644}\u{625}\u{646}\u{62c}\u{644}\u{64a}\u{632}\u{64a}\u{629}', '\u{53}\u{75}\u{62}\u{6a}\u{65}\u{63}\u{74}\u{20}\u{69}\u{6e}\u{20}\u{45}\u{6e}\u{67}\u{6c}\u{69}\u{73}\u{68}')), _field('\u{73}\u{69}\u{67}\u{6e}\u{75}\u{70}\u{54}\u{69}\u{74}\u{6c}\u{65}\u{45}\u{6e}', _tr('\u{639}\u{646}\u{648}\u{627}\u{646}\u{20}\u{627}\u{644}\u{645}\u{62d}\u{62a}\u{648}\u{649}\u{20}\u{628}\u{627}\u{644}\u{625}\u{646}\u{62c}\u{644}\u{64a}\u{632}\u{64a}\u{629}', '\u{48}\u{65}\u{61}\u{64}\u{69}\u{6e}\u{67}\u{20}\u{69}\u{6e}\u{20}\u{45}\u{6e}\u{67}\u{6c}\u{69}\u{73}\u{68}')), _field('\u{73}\u{69}\u{67}\u{6e}\u{75}\u{70}\u{42}\u{6f}\u{64}\u{79}\u{45}\u{6e}', _tr('\u{646}\u{635}\u{20}\u{627}\u{644}\u{631}\u{633}\u{627}\u{644}\u{629}\u{20}\u{628}\u{627}\u{644}\u{625}\u{646}\u{62c}\u{644}\u{64a}\u{632}\u{64a}\u{629}', '\u{4d}\u{65}\u{73}\u{73}\u{61}\u{67}\u{65}\u{20}\u{69}\u{6e}\u{20}\u{45}\u{6e}\u{67}\u{6c}\u{69}\u{73}\u{68}'), lines: 3), _field('\u{6f}\u{74}\u{70}\u{4c}\u{61}\u{62}\u{65}\u{6c}\u{45}\u{6e}', _tr('\u{62a}\u{633}\u{645}\u{64a}\u{629}\u{20}\u{627}\u{644}\u{631}\u{645}\u{632}\u{20}\u{628}\u{627}\u{644}\u{625}\u{646}\u{62c}\u{644}\u{64a}\u{632}\u{64a}\u{629}', '\u{43}\u{6f}\u{64}\u{65}\u{20}\u{6c}\u{61}\u{62}\u{65}\u{6c}\u{20}\u{69}\u{6e}\u{20}\u{45}\u{6e}\u{67}\u{6c}\u{69}\u{73}\u{68}')),
                ], icon: Icons.mark_email_read_outlined),
              ]);
              final preview = _section(_tr('معاينة مباشرة', 'Live preview'), _tr('تتحدث المعاينة مع كل تعديل.', 'Preview updates as you edit.'), [_preview()], icon: Icons.visibility_outlined);
              if (box.maxWidth < 900) return Column(children: [editor, const SizedBox(height: 16), preview]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: editor), const SizedBox(width: 18), Expanded(flex: 4, child: preview)]);
            }),
            const SizedBox(height: 20), Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_saving ? _tr('جارٍ الحفظ…', 'Saving…') : _tr('حفظ تصميم البريد', 'Save email design')))),
          ]),
        ))),
      ));
    },
  );

  Widget _logoSource() {
    final url = _controller('logoUrl').text.trim();
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [
      Container(width: 68, height: 68, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: url.startsWith('https://') ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, width: 64, height: 64, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))) : const Icon(Icons.image_outlined, size: 28)),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('شعار البريد', 'Email logo'), style: Theme.of(context).textTheme.titleSmall), Text(url.isEmpty ? _tr('يُستخدم شعار تطبيق العميل تلقائيًا عند توفره.', 'The customer app logo is used automatically when available.') : _tr('يُستخدم هذا الشعار في رسائل البريد.', 'This image is used in email messages.'), style: Theme.of(context).textTheme.bodySmall)])),
      OutlinedButton.icon(onPressed: _uploading ? null : _uploadLogo, icon: _uploading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_outlined), label: Text(_tr('رفع صورة', 'Upload image'))),
      if (url.isNotEmpty) IconButton(tooltip: _tr('استخدام شعار التطبيق', 'Use app logo'), onPressed: () => _controller('logoUrl').clear(), icon: const Icon(Icons.restart_alt)),
    ]));
  }

  void _insertVariable(String value) {
    final key = _activeField ?? (_ar ? 'signupBodyAr' : 'signupBodyEn');
    final controller = _controller(key);
    final selection = controller.selection;
    final start = selection.isValid && selection.start >= 0 ? selection.start : controller.text.length;
    final end = selection.isValid && selection.end >= start ? selection.end : start;
    controller.value = controller.value.replaced(TextRange(start: start, end: end), value).copyWith(selection: TextSelection.collapsed(offset: start + value.length));
  }

  Widget _variables() => Padding(padding: const EdgeInsets.only(bottom: 14), child: DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('متغيرات متاحة — اضغط لإضافتها في الحقل المحدد', 'Available variables — tap to insert in the selected field'), style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 6, children: [for (final value in ['{{customer_name}}', '{{app_name}}', '{{email}}', '{{otp}}']) ActionChip(label: Text(value), onPressed: () => _insertVariable(value))]), Text(_tr('تُستبدل باسم العميل واسم التطبيق والبريد ورمز التحقق.', 'Replaced with customer name, app name, email, and verification code.'), style: Theme.of(context).textTheme.bodySmall)]))));

  Widget _preview() {
    final ar = _ar;
    final logo = _controller('logoUrl').text;
    final radius = double.tryParse(_controller('cardRadius').text) ?? 18;
    return DecoratedBox(decoration: BoxDecoration(color: _previewColor('backgroundColor'), borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(12), child: DecoratedBox(decoration: BoxDecoration(color: _previewColor('surfaceColor'), borderRadius: BorderRadius.circular(radius)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_controller('showLogo').text == 'true' && logo.startsWith('https://')) Center(child: Image.network(logo, width: double.tryParse(_controller('logoWidth').text) ?? 160, height: 64, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
      Center(child: Text(_controller(ar ? 'appNameAr' : 'appNameEn').text, style: TextStyle(color: _previewColor('primaryColor'), fontWeight: FontWeight.bold))),
      const SizedBox(height: 18), Text(_controller(ar ? 'signupTitleAr' : 'signupTitleEn').text, textAlign: TextAlign.center, style: TextStyle(color: _previewColor('textColor'), fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(_controller(ar ? 'signupBodyAr' : 'signupBodyEn').text.replaceAll('{{customer_name}}', ar ? 'أحمد' : 'Alex').replaceAll('{{app_name}}', _controller(ar ? 'appNameAr' : 'appNameEn').text), textAlign: TextAlign.center, style: TextStyle(color: _previewColor('textColor'))),
      const SizedBox(height: 16), Text(_controller(ar ? 'otpLabelAr' : 'otpLabelEn').text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      Text('123456', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, letterSpacing: 8, fontWeight: FontWeight.bold, color: _previewColor('otpCodeColor'))),
      const SizedBox(height: 12), FilledButton(onPressed: null, style: FilledButton.styleFrom(backgroundColor: _previewColor('buttonColor')), child: Text(_tr('تأكيد البريد', 'Verify email'))),
      const SizedBox(height: 16), Text(_controller(ar ? 'footerAr' : 'footerEn').text.replaceAll('{{app_name}}', _controller(ar ? 'appNameAr' : 'appNameEn').text), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ])))));
  }

  Color _previewColor(String key) { final v = int.tryParse(_controller(key).text.replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF; return Color(0xFF000000 | v); }
}

