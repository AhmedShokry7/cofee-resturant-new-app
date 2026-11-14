import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// The content domain: the store content and the application settings.
List<AdminDestination> get contentDestinations => <AdminDestination>[
  AdminDestination(
    id: 'visualEditor',
    label: S.visualEditor,
    icon: AppIcons.paintBrush,
    searchHint: S.searchVisualEditorHint,
    permission: 'settings.write',
    section: S.sectionContent,
    immersive: true,
    tables: <String>['app_settings'],
  ),
  AdminDestination(
    id: 'content',
    label: S.content,
    icon: AppIcons.note01,
    searchHint: S.searchContentHint,
    permission: 'settings.write',
    section: S.sectionContent,
    tables: <String>[
      'core.legal_documents',
      'core.faq_items',
      'core.onboarding_slides',
    ],
  ),
  AdminDestination(
    id: 'appSettings',
    label: S.appSettings,
    icon: AppIcons.settings01,
    searchHint: S.searchAppSettingsHint,
    permission: 'settings.write',
    section: S.sectionContent,
    tables: <String>['core.app_settings'],
  ),
];
