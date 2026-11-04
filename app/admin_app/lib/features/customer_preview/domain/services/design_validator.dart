import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';
import 'package:admin_app/features/customer_preview/domain/registry/action_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';

/// عيب واحد وجده المدقّق، على عقدة بعينها في صفحة بعينها.
///
/// [code] هو ما تعرضه اللوحة بلغتها؛ [detail] سبب تفصيلي من فاحصة الخاصة نفسها،
/// فلا تفصيل قيمة في المستند دون أن يعرف الموظف أي عقدة وأيّ حقل. عيوب المستند
/// كله، كمخطط لا يعرفه هذا البناء، تأتي بلا صفحة ولا عقدة.
class DesignIssue {
  const DesignIssue({
    required this.code,
    this.page,
    this.nodeId,
    this.detail = '',
  });

  final DesignIssueCode code;
  final AppPage? page;
  final String? nodeId;
  final String detail;

  @override
  String toString() =>
      '${page?.key ?? 'document'}/${nodeId ?? '-'}: ${code.name}$detail';
}

/// أنواع العيوب، وهي ما تُجمَع في لوحة «قبل النشر».
enum DesignIssueCode {
  unknownType,
  missingRoot,
  wrongRootType,
  mandatoryMissing,
  mandatoryHidden,
  duplicateId,
  illegalNesting,
  emptyPage,
  emptyContainer,
  tooManyChildren,
  unknownProperty,
  invalidProperty,
  missingProperty,
  unknownDataSource,
  dataSourceRefused,
  dataSourceParameterMissing,
  unknownAction,
  actionRefused,
  actionParameterMissing,
  linkLabelWithoutAction,
  actionWithoutLabel,
  schemaVersionMismatch,
  themeTextOnSameBackground,
}

/// نتيجة تدقيق مستند كامل.
class DesignValidation {
  const DesignValidation({required this.issues, required this.schemaVersion});

  final List<DesignIssue> issues;

  /// نسخة المخطط التي يرسمها هذا البناء، وهي ما يقارَن بها المستند.
  final int schemaVersion;

  bool get isPublishable => issues.isEmpty;

  List<DesignIssue> ofPage(AppPage page) =>
      issues.where((issue) => issue.page == page).toList(growable: false);
}

/// التدقيق الذي يسبق النشر.
///
/// كل قاعدة هنا منعكسة على قرار رسم: نوع غير مسجَّل لا يُرسم، ومصدر لم تُسجَّله
/// اللوحة لا تُقرأ بياناته، ورابط بلا تسمية أو تسمية بلا رابط وعدٌ كاذب على شاشة
/// الزبون. المستند الذي يرمي هنا لا يصل إلى القاعدة، فلا يراه زبون نصفًا.
abstract final class DesignValidator {
  DesignValidator._();

  static const int _maxNodesPerPage = 60;

  static DesignValidation validate(DesignDocument document) {
    final issues = <DesignIssue>[];
    if (document.schemaVersion != WidgetRegistry.schemaVersion) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.schemaVersionMismatch,
          detail:
              '${document.schemaVersion} != ${WidgetRegistry.schemaVersion}',
        ),
      );
    }

    final seenIds = <String>{};
    for (final page in AppPage.values.where((page) => page.isEditable)) {
      final root = document.rootOf(page);
      if (root == null) {
        issues.add(DesignIssue(code: DesignIssueCode.missingRoot, page: page));
        continue;
      }
      _validateNode(
        root,
        page: page,
        parentType: null,
        seenIds: seenIds,
        issues: issues,
        isRoot: true,
      );
      if (root.children.isEmpty) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.emptyPage,
            page: page,
            nodeId: root.id,
            detail: '',
          ),
        );
      }
      _validateMandatory(page, root, issues);
    }

    _validateTheme(document, issues);

    return DesignValidation(
      issues: issues,
      schemaVersion: WidgetRegistry.schemaVersion,
    );
  }

  /// نص بلون خلفيته شاشة لا تُقرأ، وهي عيب لا يُكتشف إلا بعد النشر.
  ///
  /// الفحص على الدورين لا على قيمة: الخلفية والسطح معًا يُكتب عليهما نص، فأي
  /// تطابق بينهما وبين لون النص الأساسي يمنع النشر قبل أن يراه زبون.
  static void _validateTheme(
    DesignDocument document,
    List<DesignIssue> issues,
  ) {
    final text = document.theme.colors[DesignColorRole.textPrimary];
    if (text == null) return;
    for (final role in const <DesignColorRole>[
      DesignColorRole.background,
      DesignColorRole.surface,
    ]) {
      final ground = document.theme.colors[role];
      if (ground == null) continue;
      if (_rgb(ground) != _rgb(text)) continue;
      issues.add(
        DesignIssue(
          code: DesignIssueCode.themeTextOnSameBackground,
          detail: '${DesignColorRole.textPrimary.key} == ${role.key} ($text)',
        ),
      );
    }
  }

  /// آخر ستة عشرية من اللون، لأن `#80FFFFFF` فوق خلفية بيضاء شفافة نص أبيض.
  static String _rgb(String hex) => hex.length <= 6
      ? hex.toUpperCase()
      : hex.substring(hex.length - 6).toUpperCase();

  /// رأس الصفحة أساس في الرئيسية: لا يُنشر تصميم بلا تحية ولا بلا وقت شريط الحالة.
  static void _validateMandatory(
    AppPage page,
    DesignNode root,
    List<DesignIssue> issues,
  ) {
    for (final spec in WidgetRegistry.specs) {
      if (!spec.mandatory) continue;
      if (!spec.allowsParent(root.type)) continue;
      final found = root.children.any((child) => child.type == spec.type);
      if (!found) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.mandatoryMissing,
            page: page,
            nodeId: root.id,
            detail: spec.type,
          ),
        );
      } else if (root.children.any(
        (child) => child.type == spec.type && !child.isVisible,
      )) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.mandatoryHidden,
            page: page,
            nodeId: root.id,
            detail: spec.type,
          ),
        );
      }
    }
  }

  static void _validateNode(
    DesignNode node, {
    required AppPage page,
    required String? parentType,
    required Set<String> seenIds,
    required List<DesignIssue> issues,
    required bool isRoot,
  }) {
    final spec = WidgetRegistry.of(node.type);
    if (spec == null) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.unknownType,
          page: page,
          nodeId: node.id,
          detail: node.type,
        ),
      );
      return;
    }
    if (!seenIds.add(node.id)) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.duplicateId,
          page: page,
          nodeId: node.id,
          detail: '',
        ),
      );
    }

    if (isRoot) {
      final expected = WidgetRegistry.rootTypeOf(page);
      if (node.type != expected) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.wrongRootType,
            page: page,
            nodeId: node.id,
            detail: expected,
          ),
        );
      }
    } else if (parentType != null) {
      final parent = WidgetRegistry.of(parentType);
      final parentRefuses =
          parent == null ||
          !parent.canHaveChildren ||
          !parent.allowsChild(node.type);
      if (parentRefuses || !spec.allowsParent(parentType)) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.illegalNesting,
            page: page,
            nodeId: node.id,
            detail: '$parentType ← ${node.type}',
          ),
        );
      }
    }

    _validateProperties(node, spec, page, issues);
    _validateDataSource(node, spec, page, issues);
    _validateAction(node, spec, page, issues);

    if (spec.canHaveChildren && node.children.isEmpty) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.emptyContainer,
          page: page,
          nodeId: node.id,
          detail: '',
        ),
      );
    }
    if (node.children.length > _maxNodesPerPage) {
      // السقف قرار رسم لا ذوق: صفحة بأبناء أكثر من هذا تُبطئ الهاتف داخل اللوحة.
      issues.add(
        DesignIssue(
          code: DesignIssueCode.tooManyChildren,
          page: page,
          nodeId: node.id,
          detail: '${node.children.length} > $_maxNodesPerPage',
        ),
      );
    }

    for (final child in node.children) {
      _validateNode(
        child,
        page: page,
        parentType: node.type,
        seenIds: seenIds,
        issues: issues,
        isRoot: false,
      );
    }
  }

  static void _validateProperties(
    DesignNode node,
    WidgetSpec spec,
    AppPage page,
    List<DesignIssue> issues,
  ) {
    for (final key in node.properties.keys) {
      if (spec.property(key) == null) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.unknownProperty,
            page: page,
            nodeId: node.id,
            detail: key,
          ),
        );
      }
    }
    for (final property in spec.properties) {
      final value = node.properties[property.key];
      final reason = property.reject(value);
      if (reason == null) continue;
      issues.add(
        DesignIssue(
          code: value == null
              ? DesignIssueCode.missingProperty
              : DesignIssueCode.invalidProperty,
          page: page,
          nodeId: node.id,
          detail: '${property.key}: $reason',
        ),
      );
    }
  }

  static void _validateDataSource(
    DesignNode node,
    WidgetSpec spec,
    AppPage page,
    List<DesignIssue> issues,
  ) {
    final key = node.stringProperty('dataSource');
    if (key.isEmpty) return;
    final source = DataSourceRegistry.of(key);
    if (source == null) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.unknownDataSource,
          page: page,
          nodeId: node.id,
          detail: key,
        ),
      );
      return;
    }
    if (!spec.dataSourceKeys.contains(key)) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.dataSourceRefused,
          page: page,
          nodeId: node.id,
          detail: '${spec.type} ← $key',
        ),
      );
      return;
    }
    final parameter = source.needsParameter;
    if (parameter == null) return;
    if (page.supplies(parameter)) return;
    if (node.stringProperty(parameter).isEmpty) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.dataSourceParameterMissing,
          page: page,
          nodeId: node.id,
          detail: parameter,
        ),
      );
    }
  }

  static void _validateAction(
    DesignNode node,
    WidgetSpec spec,
    AppPage page,
    List<DesignIssue> issues,
  ) {
    final actionKey = node.stringProperty('action');
    if (actionKey.isEmpty) return;
    final action = ActionRegistry.of(actionKey);
    if (action == null) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.unknownAction,
          page: page,
          nodeId: node.id,
          detail: actionKey,
        ),
      );
      return;
    }
    if (!spec.actionKeys.contains(actionKey)) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.actionRefused,
          page: page,
          nodeId: node.id,
          detail: '${spec.type} ← $actionKey',
        ),
      );
      return;
    }

    // إجراء يشير شيئًا لا يملك المكوّن خاصية تحمله: الهوية حينها من الصف الملموس.
    final parameter = action.needsParameter;
    if (parameter != null &&
        spec.property(parameter) != null &&
        node.stringProperty(parameter).isEmpty) {
      issues.add(
        DesignIssue(
          code: DesignIssueCode.actionParameterMissing,
          page: page,
          nodeId: node.id,
          detail: '$actionKey ← $parameter',
        ),
      );
    }

    // رابط المقطع: تسمية بلا إجراء زر لا ينفّذ، وإجراء بلا تسمية نقطة ضغط خفية.
    final hasLinkLabel = spec.property('linkLabel') != null;
    final hasAction = spec.property('action') != null;
    if (hasLinkLabel && hasAction) {
      final label = node.stringProperty('linkLabel').trim();
      if (actionKey == ActionRegistry.none && label.isNotEmpty) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.linkLabelWithoutAction,
            page: page,
            nodeId: node.id,
            detail: label,
          ),
        );
      }
      if (actionKey != ActionRegistry.none && label.isEmpty) {
        issues.add(
          DesignIssue(
            code: DesignIssueCode.actionWithoutLabel,
            page: page,
            nodeId: node.id,
            detail: actionKey,
          ),
        );
      }
    }
  }
}
