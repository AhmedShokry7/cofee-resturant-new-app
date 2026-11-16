import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/app.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
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
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/email_auth_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/shipping_addresses_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/add_address_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_method_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/payment_success_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/e_receipt_page.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/views/saved_cards_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/profile/presentation/views/edit_profile_page.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/addresses/presentation/views/address_form_page.dart';
import 'package:new_coffee/features/content/presentation/views/help_page.dart';
import 'package:new_coffee/features/content/presentation/views/privacy_policy_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notification_settings_page.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_memory_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/cashier_subscription_consume_page.dart';

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

  /// الصفحة التي يشاهدها الموظف في المحاكي الآن — شجرتها هي التي تُرسل
  /// راجعة إلى لوحة الطبقات. الافتتاحية دائمًا الرئيسية.
  String _currentPreviewPage = 'home';

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
    // الشجرة تُرسل للصفحة التي يشاهدها الموظف في المحاكي، لا الرئيسية دائمًا:
    // لوحة الطبقات تتزامن مع ما يرسم الهاتف فعليًا لكل صفحة على حدة.
    final pageId = _currentPreviewPage;
    final root = design.toDocument()['pages'] as List?;
    if (root is! List || root.isEmpty) return;
    final page = root.firstWhere(
      (entry) => entry is Map && entry['page'] == pageId,
      orElse: () => null,
    );
    if (page is! Map) return;
    final children = page['root'] is Map
        ? (page['root'] as Map)['children']
        : null;
    if (children is! List) return;
    _bridge.sendTreeUpdated(
      pageId: pageId,
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
    // الصفحة المعروضة الآن هي التي تُبلّغ شجرتها الراجعة إلى المحرّر.
    _currentPreviewPage = pageId;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    // التبويبات الخمسة تُفتح بإعادة فتح MainPage بتبويبها — نفس ما يستدعي
    // التطبيق نفسه، وinitialTab يقرأه MainPage الجديد عند إنشائه.
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
      default:
        // كل شاشة أخرى لها مسار ثابت بلا وسيطات — يُفتح من جديد فوق
        // الجذر، فلا تتراكم رصة من معاينة إلى أخرى، وتبقى زر الرجوع
        // يصل للجذر لا لشاشة سابقة في المعاينة.
        final routeName = pageRoutes[pageId];
        if (routeName == null) return;
        navigator.pushNamedAndRemoveUntil(routeName, (route) => route.isFirst);
        return;
    }
    // MainCubit الجديد يقرأ initialTab عند الإنشاء، لذا إعادة فتح الصفحة
    // الرئيسية مع إبقاء الجذر هي الانتقال الحقيقي بين التبويبات.
    navigator.pushNamedAndRemoveUntil(
      MainPage.routeName,
      (route) => route.isFirst,
    );
  }

  /// كل شاشات التطبيق التي تُبنى بمسارها الثابت بلا كائنات — كما في
  /// `AppRoutes.routes`. الشاشات ذات الوسيطات (تفاصيل منتج، طلب، باقة…)
  /// تُفتح من داخل شاشاتها ولا تُبنى من مسار مجهول الحمولة.
  static const Map<String, String> pageRoutes = {
    'splash': SplashView.routeName,
    'welcome': WelcomePage.routeName,
    'onboarding': OnBoardingView.routeName,
    'auth': AuthPage.routeName,
    'sign_up': SignUpPage.routeName,
    'forget_password': ForgetPasswordPage.routeName,
    'reset_password': ResetPasswordPage.routeName,
    'phone_auth': PhoneAuthPage.routeName,
    'email_auth': EmailAuthPage.routeName,
    'checkout': CheckoutPage.routeName,
    'shipping_addresses': ShippingAddressesPage.routeName,
    'add_address': AddAddressPage.routeName,
    'payment_method': PaymentMethodPage.routeName,
    'add_card': AddCardPage.routeName,
    'payment_success': PaymentSuccessPage.routeName,
    'e_receipt': EReceiptPage.routeName,
    'coupon': CouponPage.routeName,
    'loyalty': LoyaltyPage.routeName,
    'orders': OrdersPage.routeName,
    'edit_profile': EditProfilePage.routeName,
    'saved_cards': SavedCardsPage.routeName,
    'addresses': AddressesPage.routeName,
    'address_form': AddressFormPage.routeName,
    'help': HelpPage.routeName,
    'privacy': PrivacyPolicyPage.routeName,
    'notifications': NotificationsPage.routeName,
    'notification_settings': NotificationSettingsPage.routeName,
    'assistant_memory': AssistantMemoryPage.routeName,
    'subscription_plans': SubscriptionPlansPage.routeName,
    'subscription_details': SubscriptionDetailsPage.routeName,
    'cashier_subscription': CashierSubscriptionConsumePage.routeName,
  };

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
    // المعاينة يبدأ من الشاشة الرئيسية دائمًا. التوجيه نفسه في الكود الحقيقي:
    // الزائر المجهول يُوجّه لتسجيل الدخول، أما المعاينة فتجتاز ذلك بمسار
    // الرئيسية صراحة — نفس MyApp ونفس MainPage، بلا شاشة دخول داخل الإطار.
    return MyApp(
      currentRoute: AppConstant.homeRoute,
      onboardingDone: true,
    );
  }
}
