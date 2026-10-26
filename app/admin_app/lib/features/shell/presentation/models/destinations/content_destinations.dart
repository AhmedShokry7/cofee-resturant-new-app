import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// The content domain: the store content and the application settings.
List<AdminDestination> get contentDestinations => <AdminDestination>[
  AdminDestination(
    id: 'content',
    label: S.content,
    icon: HugeIcons.strokeRoundedNote01,
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
    icon: HugeIcons.strokeRoundedSettings01,
    searchHint: S.searchAppSettingsHint,
    permission: 'settings.write',
    section: S.sectionContent,
    tables: <String>['core.app_settings'],
  ),
  AdminDestination(
    id: 'customerPreview',
    label: S.customerPreview,
    icon: HugeIcons.strokeRoundedSmartPhone01,
    searchHint: S.customerPreviewHint,
    permission: 'settings.write',
    section: S.sectionContent,
    tables: <String>['core.app_settings'],
  ),
];
