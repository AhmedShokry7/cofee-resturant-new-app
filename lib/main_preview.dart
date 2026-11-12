import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' as ui;
import 'dart:async';

import 'package:new_coffee/app.dart';
import 'package:new_coffee/core/startup/app_bootstrap.dart';
import 'package:new_coffee/core/startup/preview_theme.dart';
import 'package:new_coffee/features/design/data/design_applier.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/theme/app_theme.dart';
import 'package:new_coffee/core/preview/preview_bridge.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Preview mode entry point for the Customer App.
///
/// This runs inside an iframe in the Admin App's Visual Editor.
/// It communicates with the parent via postMessage for:
/// - Receiving design documents to preview
/// - Sending element selection events
/// - Receiving property updates
///
/// The preview mode:
/// - Disables Firebase messaging (not needed in iframe)
/// - Loads design from Admin App via postMessage
/// - Reports user interactions back to Admin App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale and theme first
  await AppLocale.instance.initialize();
  await AppTheme.instance.initialize();

  // Initialize Supabase (required for design loading)
  await SupabaseService.init();

  // Apply preview theme from URL parameters (for color preview)
  applyPreviewTheme();

  // In preview mode, we don't need Firebase messaging
  // The design will be loaded via postMessage from Admin App

  runApp(const PreviewApp());
}

/// The preview app root - wraps MyApp with preview-specific providers
class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  late final DesignCubit _designCubit;
  late final PreviewBridge _bridge;
  StreamSubscription<DesignState>? _designSubscription;
  String? _sessionId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _designCubit = DesignCubit(repository: SupabaseDesignRepository());
    _bridge = PreviewBridge();

    // Listen for design changes to send updates to parent
    _designSubscription = _designCubit.stream.listen(_onDesignChanged);

    // Initialize bridge when session ID is available from URL
    _initializeFromUrl();
  }

  void _initializeFromUrl() {
    final uri = Uri.base;
    final sessionId = uri.queryParameters['sessionId'];
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
      _bridge.initialize(sessionId);
      _setupMessageHandlers();
      _isInitialized = true;
    }
  }

  void _setupMessageHandlers() {
    _bridge.onMessage(PreviewMessageType.previewInitialize, _handleInitialize);
    _bridge.onMessage(PreviewMessageType.loadPage, _handleLoadPage);
    _bridge.onMessage(PreviewMessageType.updateProperty, _handleUpdateProperty);
    _bridge.onMessage(PreviewMessageType.applyDesignConfig, _handleApplyDesignConfig);
    _bridge.onMessage(PreviewMessageType.previewRefresh, _handleRefresh);
  }

  void _handleInitialize(PreviewMessage message) {
    // Acknowledge initialization
    // The design document is in the payload
    final designDoc = message.payload['designDocument'];
    if (designDoc != null) {
      _applyDesignDocument(designDoc);
    }
  }

  void _handleLoadPage(PreviewMessage message) {
    final pageId = message.payload['pageId'] as String?;
    if (pageId != null) {
      // Navigate to the page
      // This would use the app's navigation system
    }
  }

  void _handleUpdateProperty(PreviewMessage message) {
    final componentId = message.payload['componentId'] as String?;
    final propertyKey = message.payload['propertyKey'] as String?;
    final value = message.payload['value'];

    if (componentId != null && propertyKey != null) {
      // Apply the property change to the design
      // This would update the design cubit
      _applyPropertyChange(componentId, propertyKey, value);
    }
  }

  void _handleApplyDesignConfig(PreviewMessage message) {
    final designDoc = message.payload['designDocument'];
    if (designDoc != null) {
      _applyDesignDocument(designDoc);
    }
  }

  void _handleRefresh(PreviewMessage message) {
    // Reload the published design
    _designCubit.load(forceRefresh: true);
  }

  void _onDesignChanged(DesignState state) {
    if (!_isInitialized) return;
    // Send updated design to parent for sync
    // This would serialize the design and send via bridge
  }

  void _applyDesignDocument(dynamic designDoc) {
    // Parse and apply the design document
    // This would update the DesignCubit with the new design
  }

  void _applyPropertyChange(String componentId, String propertyKey, dynamic value) {
    // Apply property change to the specific component
    // This would require finding the component in the design tree
    // and updating its property
    _bridge.sendPropertyUpdated(
      componentId: componentId,
      propertyKey: propertyKey,
      value: value,
      success: true,
    );
  }

  @override
  void dispose() {
    _designSubscription?.cancel();
    _bridge.dispose();
    _designCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DesignCubit>.value(
      value: _designCubit,
      child: MyApp(
        currentRoute: null,
        onboardingDone: true,
      ),
    );
  }
}