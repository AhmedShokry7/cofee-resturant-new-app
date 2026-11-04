import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// The content domain: the store content and the application settings.
List<AdminDestination> get contentDestinations => <AdminDestination>[
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
  AdminDestination(
    id: 'customerPreview',
    label: S.customerPreview,
    icon: AppIcons.smartPhone01,
    searchHint: S.customerPreviewHint,
    permission: 'settings.write',
    section: S.sectionContent,
    tables: <String>['core.app_settings'],
  ),
  AdminDestination(
    id: 'appBuilder',
    label: S.appBuilder,
    icon: AppIcons.gridView,
    searchHint: S.appBuilderHint,
    // 226: اللوحة كلها تُقرأ بصلاحية التحرير، فمن لا يقرأ المسودة لا يرى
    // شجرة ولا ألواحًا تنطفئ أمامه.
    permission: 'design.edit',
    section: S.sectionContent,
    tables: <String>['core.app_settings', 'core.app_design_versions'],
    // لوحة بثلاثة أعمدة وجهاز في وسطها: الشريط الجانبي الدائم يضغط الهاتف
    // نفسه، فيؤخذ مكانه كما أُخذ في الصُّدّادة.
    immersive: true,
  ),
];
