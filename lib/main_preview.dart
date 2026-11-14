import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/app.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/preview/preview_bridge.dart';
import 'package:new_coffee/core/preview/preview_section.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/startup/preview_theme.dart';
import 'package:new_coffee/features/design/data/design_preview_store.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';

/// Preview mode entry point for the Customer App.
///
/// This runs inside an iframe in the Admin App's Visual Editor — the app
/// itself, not a copy of it. The editor drives it through [PreviewBridge]:
///
/// - PREVIEW_INITIALIZE / APPLY_DESIGN_CONFIG / UPDATE_PROPERTY / ADD /
///   REMOVE / REORDER: apply the document the editor sends through
///   [DesignPreviewStore], so the preview goes through the exact pipeline
///   the phone uses for a published design.
/// - LOAD_PAGE: opens the tab the editor asked for.
/// - SELECT_ELEMENT: highlights the section the editor pointed at.
/// - PREVIEW_READY / ELEMENT_SELECTED / PROPERTY_UPDATED / TREE_UPDATED:
///   flow back to the editor.
///
/// The design never persists from here: the store is memory-only, so closing
/// the preview leaves the published design as it is.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale first: the app below reads it on the first frame.
  await AppLocale.instance.initialize();
  // Supabase is required by repositories the app builds (design reads, auth
  // reconnects). Without configuration the repositories fall back the same
  // way they do for a customer without a backend.
  await SupabaseService.init();
  applyPreviewTheme();

  runApp(const PreviewApp());
}

/// The preview root: wraps the real [MyApp] with nothing but preview wiring.
class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  final PreviewBridge _bridge = PreviewBridge();
  StreamSubscription<DesignState>? _designSubscription;

  @override
  void initState() {
    super.initState();
    _initializeFromUrl();
  }

  @override
  void dispose() {
    _designSubscription?.cancel();
    _bridge.dispose();
    super.dispose();
  }

  void _initializeFromUrl() {
    if (!kIsWeb) return;
    final uri = Uri.base;
    final sessionId = uri.queryParameters['sessionId'];
    if (sessionId == null || sessionId.isEmpty) return;
    _bridge.initialize(
      sessionId,
      parentOrigin: uri.queryParameters['parentOrigin'],
    );
    _setupMessageHandlers();
  }

  void _setupMessageHandlers() {
    _bridge
      ..onMessage(PreviewMessageType.previewInitialize, _applyDocument)
      ..onMessage(PreviewMessageType.applyDesignConfig, _applyDocument)
      ..onMessage(PreviewMessageType.updateProperty, _applyDocument)
      ..onMessage(PreviewMessageType.addComponent, _applyDocument)
      ..onMessage(PreviewMessageType.removeComponent, _applyDocument)
      ..onMessage(PreviewMessageType.reorderComponent, _applyDocument)
      ..onMessage(PreviewMessageType.loadPage, _handleLoadPage)
      ..onMessage(PreviewMessageType.selectElement, _handleSelectElement)
      ..onMessage(PreviewMessageType.previewRefresh, _handleRefresh);
    _watchDesignForTreeUpdates();
  }

  /// كل تغيّر في مستند المعاينة يُبلّغ به المحرّر (COMPONENT_TREE_UPDATED)
  /// حتى تظل لوحة الطبقات متزامنة مع ما يرسمه الهاتف.
  void _watchDesignForTreeUpdates() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context == null || !mounted) return;
      _designSubscription = context
          .read<DesignCubit>()
          .stream
          .listen((_) => _sendTreeUpdate());
    });
  }

  void _sendTreeUpdate() {
    if (!_bridge.isActive) return;
    final document = DesignPreviewStore.instance.document;
    if (document == null) return;
    final design = PublishedDesign.fromJson(document);
    if (design == null) return;
    final root = design.toDocument()['pages'] as List?;
    if (root is! List || root.isEmpty) return;
    final page = root.first;
    if (page is! Map) return;
    final children = page['root'] is Map
        ? (page['root'] as Map)['children']
        : null;
    if (children is! List) return;
    _bridge.sendTreeUpdated(
      pageId: 'home',
      nodes: [
        for (final node in children)
          if (node is Map)
            Map<String, dynamic>.from(node)
          else
            <String, dynamic>{},
      ],
    );
  }

  /// أي رسالة تحرير تحمل `designDocument` في حمولتها تطبّق كاملة: المحرّر
  /// يملك حالة الوثيقة، والهاتف يرسم ما أُرسل لا ما خمّنه.
  void _applyDocument(PreviewMessage message) {
    final raw = message.payload['designDocument'];
    if (raw is! Map) {
      _bridge.sendPropertyUpdated(
        componentId: message.payload['componentId'] as String? ?? '',
        propertyKey: message.payload['propertyKey'] as String? ?? '',
        value: message.payload['value'],
        success: false,
        error: 'design_document_missing',
      );
      return;
    }
    final document = Map<String, dynamic>.from(raw);
    DesignPreviewStore.instance.setDocument(document);
    // المسار نفسه الذي يرسم به الهاتف يوم النشر: قراءة المنشور، ثم تطبيق
    // الطبقة، ثم إعادة بناء الشاشة.
    BlocProvider.of<DesignCubit>(rootNavigatorKey.currentContext!)
        .load(forceRefresh: true);
    _ack(message);
  }

  /// تأكيد رسالة تحرير واحدة — الرسالة كلها طبّقت كاملة.
  void _ack(PreviewMessage message) {
    _bridge.sendPropertyUpdated(
      componentId: message.payload['componentId'] as String? ?? '',
      propertyKey: message.payload['propertyKey'] as String? ?? '',
      value: message.payload['value'],
      success: true,
    );
  }

  void _handleLoadPage(PreviewMessage message) {
    final pageId = message.payload['pageId'];
    if (pageId is! String) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    switch (pageId) {
      case 'home':
        MainCubit.initialTab = 0;
      case 'categories':
        MainCubit.initialTab = 1;
      case 'cart':
        MainCubit.initialTab = 2;
      case 'favourites':
        MainCubit.initialTab = 3;
      case 'settings':
        MainCubit.initialTab = 4;
      case 'search':
        // البحث صفحة مدفوعة لا تبويبة، كما يستدعيها التطبيق نفسه.
        navigator.pushNamed(SearchPage.routeName);
        return;
      default:
        return;
    }
    // MainCubit الجديد يقرأ initialTab عند الإنشاء، لذا إعادة فتح الصفحة
    // الرئيسية مع إبقاء الجذر هي الانتقال الحقيقي بين التبويبات.
    navigator.pushNamedAndRemoveUntil(
      MainPage.routeName,
      (route) => route.isFirst,
    );
  }

  void _handleSelectElement(PreviewMessage message) {
    final componentId = message.payload['componentId'];
    if (componentId is String) previewSelectedSectionId.value = componentId;
  }

  void _handleRefresh(PreviewMessage message) {
    // الرجوع إلى المنشور الحقيقي: مسح المستند المُدفع، ثم القراءة من القاعدة.
    DesignPreviewStore.instance.setDocument(null);
    BlocProvider.of<DesignCubit>(rootNavigatorKey.currentContext!)
        .load(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    // يقرأ المنشور عند الإقلاع — بلا currentRoute ولا onboarding، لأن إطار
    // المعاينة يبدأ من الشاشة الرئيسية دائمًا.
    return MyApp(
      currentRoute: null,
      onboardingDone: true,
    );
  }
}
