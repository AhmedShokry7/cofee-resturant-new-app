import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';

/// لماذا يرفض المحرّر عملية على الشجرة، حتى تقول اللوحة السبب لا «لا» وحدها.
enum DesignEditRejection {
  none,

  /// نوع غير مسجَّل: لا يُرسم، فلا يُضاف.
  unknownType,

  /// العقدة المطلوبة غير موجودة في الصفحة.
  missingNode,

  /// الأب ليس حاوية يقبل المحرّر أن يُفلت فيها.
  parentIsNotContainer,

  /// الأب مسجَّل لكنه لا يذكر هذا النوع بين أبنائه.
  parentRefusesChild,

  /// الابن لا يذكر هذا الأب بين من يقبلهم.
  childRefusesParent,

  /// مكوّن أساس مقفول: لا يُنقل ولا يُخفى ولا يُحذف.
  lockedComponent,

  /// حاوية تُفلت داخل أحد أبنائها، فتُقطع الشجرة على نفسها.
  intoOwnDescendant,

  /// حاوية فيها أبناء؛ تُفرَّغ أولًا حتى لا يختفي ابن بلا إعلان.
  containerNotEmpty,

  /// طبقة بلا اسم في الشجرة: المعرّف الفارغ لا يُقرأ ولا يُشار إليه.
  emptyId,

  /// اسم أخذته طبقة أخرى: التحديد والحذف والإفلات تُشار بالمعرّف، فاسم مكرَّر
  /// يعني عملة على طبقتين.
  duplicateId,

  /// المحرّر في وضع المشاهدة: النقر يعمل كما عند الزبون، والبناء لا.
  previewMode,

  /// صفحة مقفلة لا تُحرَّر، فلا معنى للتعديل عليها.
  pageNotEditable,
}

/// عمليات على شجرة صفحة واحدة، وكلها ترجع نسخة جديدة.
///
/// الثبات هنا شرط لا أناقة: Undo والـ Redo يخزّنان المستندات السابقة، فلو بدّلت
/// عملية واحدة الشجرة في مكانها لبدّلت نسخة محفوظة معه.
///
/// مؤشرات الإفلات في اللوحة تُحسب على قائمة الأبناء بعد إخراج العقدة المنقولة،
/// وهو ما يفعله [move] بالضبط، فيبقى ما يراه الموظف هو ما يحدث.
abstract final class DesignTree {
  DesignTree._();

  static DesignNode? find(DesignNode root, String id) {
    if (root.id == id) return root;
    for (final child in root.children) {
      final hit = find(child, id);
      if (hit != null) return hit;
    }
    return null;
  }

  /// أب العقدة، أو null حين كانت الجذر الذي لا أب له.
  static DesignNode? parentOf(DesignNode root, String id) {
    if (root.id == id) return null;
    for (final child in root.children) {
      if (child.id == id) return root;
      final hit = parentOf(child, id);
      if (hit != null) return hit;
    }
    return null;
  }

  static bool isDescendant(DesignNode node, String id) =>
      find(node, id) != null;

  /// كل معرّفات الشجرة، لفحص التفرّد قبل توليد معرّف جديد.
  static Set<String> idsOf(DesignNode root) => <String>{
    for (final node in _walk(root)) node.id,
  };

  static DesignNode update(
    DesignNode root,
    String id,
    DesignNode Function(DesignNode node) transform,
  ) {
    if (root.id == id) return transform(root);
    if (root.children.isEmpty) return root;
    return root.copyWith(
      children: <DesignNode>[
        for (final child in root.children) update(child, id, transform),
      ],
    );
  }

  static DesignNode insert(
    DesignNode root,
    String parentId,
    int index,
    DesignNode child,
  ) => update(root, parentId, (parent) {
    return parent.copyWith(children: _insertAt(parent.children, index, child));
  });

  static DesignNode remove(DesignNode root, String id) {
    final parent = parentOf(root, id);
    if (parent == null) return root;
    return update(root, parent.id, (node) {
      return node.copyWith(
        children: <DesignNode>[
          for (final child in node.children)
            if (child.id != id) child,
        ],
      );
    });
  }

  /// نقل عقدة موجودة. لا يحرّك مقفولًا ولا يُسقط حاوية في بطن أحد أبنائها.
  static DesignNode move(
    DesignNode root,
    String id,
    String newParentId,
    int index,
  ) {
    if (rejectionOfMove(root, id, newParentId) != DesignEditRejection.none) {
      return root;
    }
    final node = find(root, id)!;
    return insert(remove(root, id), newParentId, index, node);
  }

  /// نسخة جديدة من العقدة وأبنائها، بمعرّفات لم تأخذها عقدة أخرى، تليها مباشرة.
  static DesignNode duplicate(DesignNode root, String id) {
    final source = find(root, id);
    final parent = parentOf(root, id);
    if (source == null || parent == null) return root;
    if (isLocked(source.type)) return root;

    final taken = idsOf(root);
    final clone = _renew(source, taken, base: source.id);
    final at = parent.children.indexWhere((child) => child.id == id) + 1;
    return insert(root, parent.id, at, clone);
  }

  static DesignNode setProperty(
    DesignNode root,
    String id,
    String key,
    Object? value,
  ) => update(root, id, (node) => node.withProperty(key, value));

  static DesignNode setVisible(DesignNode root, String id, bool isVisible) {
    final node = find(root, id);
    if (node == null || isLocked(node.type)) return root;
    return update(
      root,
      id,
      (current) => current.copyWith(isVisible: isVisible),
    );
  }

  /// سبب رفض إعادة تسمية طبقة، أو [DesignEditRejection.none] حين يُقبل الاسم.
  /// الاسم هنا هو معرّف العقدة في المستند، لا نص يراه الزبون: به تُحدَّد الطبقة
  /// وتُنقل، فلا يقبل فراغًا ولا اسمًا مأخوذًا.
  static DesignEditRejection rejectionOfRename(
    DesignNode root,
    String id,
    String newId,
  ) {
    final node = find(root, id);
    if (node == null) return DesignEditRejection.missingNode;
    if (isLocked(node.type)) return DesignEditRejection.lockedComponent;
    final renamed = newId.trim();
    if (renamed.isEmpty) return DesignEditRejection.emptyId;
    if (renamed == id) return DesignEditRejection.none;
    return idsOf(root).contains(renamed)
        ? DesignEditRejection.duplicateId
        : DesignEditRejection.none;
  }

  /// معرّف جديد للطبقة. لا يمسّ نوعها ولا خصائصها ولا أبناءها: ما يراه الزبون
  /// من رسم لا يتغيّر باسم في الشجرة.
  static DesignNode rename(DesignNode root, String id, String newId) {
    if (rejectionOfRename(root, id, newId) != DesignEditRejection.none) {
      return root;
    }
    return update(root, id, (node) => node.copyWith(id: newId.trim()));
  }

  /// legality إضافة عنصر من المكتبة أو إفلاته.
  static DesignEditRejection rejectionOfAttach({
    required DesignNode root,
    required String parentId,
    required String childType,
  }) {
    final childSpec = WidgetRegistry.of(childType);
    if (childSpec == null) return DesignEditRejection.unknownType;
    final parent = find(root, parentId);
    if (parent == null) return DesignEditRejection.missingNode;
    final parentSpec = WidgetRegistry.of(parent.type);
    if (parentSpec == null) return DesignEditRejection.unknownType;
    if (!parentSpec.canHaveChildren) {
      return DesignEditRejection.parentIsNotContainer;
    }
    if (!parentSpec.allowsChild(childType)) {
      return DesignEditRejection.parentRefusesChild;
    }
    if (!childSpec.allowsParent(parentSpec.type)) {
      return DesignEditRejection.childRefusesParent;
    }
    return DesignEditRejection.none;
  }

  static DesignEditRejection rejectionOfMove(
    DesignNode root,
    String id,
    String newParentId,
  ) {
    final node = find(root, id);
    if (node == null) return DesignEditRejection.missingNode;
    if (isLocked(node.type)) return DesignEditRejection.lockedComponent;
    final newParent = find(root, newParentId);
    if (newParent == null) return DesignEditRejection.missingNode;
    // داخل نفسها أو داخل أحد أبنائها: الشجرة تنقطع والعقدة تختفي من اللوحة.
    if (newParentId == id || isDescendant(node, newParentId)) {
      return DesignEditRejection.intoOwnDescendant;
    }
    return rejectionOfAttach(
      root: root,
      parentId: newParentId,
      childType: node.type,
    );
  }

  static DesignEditRejection rejectionOfRemove(DesignNode root, String id) {
    final node = find(root, id);
    if (node == null) return DesignEditRejection.missingNode;
    if (isLocked(node.type)) return DesignEditRejection.lockedComponent;
    // حاوية بأبناء لا تُحذف بصمت: الموظف يفرّغها أولًا حتى لا يختفي ابن بلا إعلان.
    if (node.children.isNotEmpty) {
      return DesignEditRejection.containerNotEmpty;
    }
    return DesignEditRejection.none;
  }

  static bool isLocked(String type) {
    final spec = WidgetRegistry.of(type);
    if (spec == null) return false;
    return spec.mandatory || spec.level == WidgetEditLevel.locked;
  }

  /// معرّف لا يصطدم بواحد موجود: `home_banners` ثم `home_banners-2`.
  static String freshId(Iterable<String> taken, String base) {
    final used = taken is Set<String> ? taken : Set<String>.of(taken);
    if (!used.contains(base)) return base;
    var next = 2;
    while (used.contains('$base-$next')) {
      next++;
    }
    return '$base-$next';
  }

  /// اسم العنصر من نوعه المسجَّل: `section.product_strip` إلى `product_strip`.
  static String baseOf(String type) => type.substring(type.lastIndexOf('.') + 1);

  static DesignNode _renew(DesignNode node, Set<String> taken, {String? base}) {
    final id = freshId(taken, base ?? baseOf(node.type));
    taken.add(id);
    return node.copyWith(
      id: id,
      children: <DesignNode>[
        for (final child in node.children) _renew(child, taken),
      ],
    );
  }

  static List<DesignNode> _insertAt(
    List<DesignNode> children,
    int index,
    DesignNode child,
  ) {
    final next = List<DesignNode>.of(children);
    final at = index.clamp(0, next.length);
    next.insert(at, child);
    return next;
  }

  static Iterable<DesignNode> _walk(DesignNode node) sync* {
    yield node;
    for (final child in node.children) {
      yield* _walk(child);
    }
  }
}

/// العمليات على مستوى المستند كله: الصفحة تُحدَّد أولًا، ثم تُطبَّق عملية على
/// جذرها، فيبقى Cubit بعيدًا عن تفاصيل الشجرة.
abstract final class DesignDocumentEdit {
  DesignDocumentEdit._();

  /// تطبيق عملية على جذور صفحة؛ صفحة مقفلة أو بلا جذر ترجع كما هي.
  static DesignDocument editPage(
    DesignDocument document,
    AppPage page,
    DesignNode Function(DesignNode root) transform,
  ) {
    final root = document.rootOf(page);
    if (root == null || !page.isEditable) return document;
    return document.withPage(page, transform(root));
  }

  static DesignEditRejection attachRejection(
    DesignDocument document,
    AppPage page, {
    required String parentId,
    required String childType,
  }) {
    if (!page.isEditable) return DesignEditRejection.pageNotEditable;
    final root = document.rootOf(page);
    if (root == null) return DesignEditRejection.missingNode;
    return DesignTree.rejectionOfAttach(
      root: root,
      parentId: parentId,
      childType: childType,
    );
  }

  static DesignDocument insert(
    DesignDocument document,
    AppPage page, {
    required String parentId,
    required int index,
    required DesignNode child,
  }) => editPage(
    document,
    page,
    (root) => DesignTree.insert(root, parentId, index, child),
  );

  static DesignDocument move(
    DesignDocument document,
    AppPage page, {
    required String id,
    required String newParentId,
    required int index,
  }) => editPage(
    document,
    page,
    (root) => DesignTree.move(root, id, newParentId, index),
  );

  static DesignDocument remove(
    DesignDocument document,
    AppPage page,
    String id,
  ) => editPage(document, page, (root) => DesignTree.remove(root, id));

  static DesignDocument duplicate(
    DesignDocument document,
    AppPage page,
    String id,
  ) => editPage(document, page, (root) => DesignTree.duplicate(root, id));

  /// إعادة تسمية على مستوى المستند: الاسم لا يجوز أن يصطدم بطبقة في صفحة أخرى،
  /// لأن المدقّق يفرد المعرّفات على كل الصفحات.
  static DesignEditRejection renameRejection(
    DesignDocument document,
    AppPage page,
    String id,
    String newId,
  ) {
    if (!page.isEditable) return DesignEditRejection.pageNotEditable;
    final root = document.rootOf(page);
    if (root == null) return DesignEditRejection.missingNode;
    final rejection = DesignTree.rejectionOfRename(root, id, newId);
    if (rejection != DesignEditRejection.none) return rejection;
    final renamed = newId.trim();
    final clash = document.pages.entries.any(
      (entry) =>
          entry.key != page && DesignTree.isDescendant(entry.value, renamed),
    );
    return clash ? DesignEditRejection.duplicateId : DesignEditRejection.none;
  }

  static DesignDocument rename(
    DesignDocument document,
    AppPage page, {
    required String id,
    required String newId,
  }) => editPage(
    document,
    page,
    (root) => DesignTree.rename(root, id, newId),
  );

  static DesignDocument setProperty(
    DesignDocument document,
    AppPage page, {
    required String id,
    required String key,
    required Object? value,
  }) => editPage(
    document,
    page,
    (root) => DesignTree.setProperty(root, id, key, value),
  );

  static DesignDocument setVisible(
    DesignDocument document,
    AppPage page, {
    required String id,
    required bool isVisible,
  }) => editPage(
    document,
    page,
    (root) => DesignTree.setVisible(root, id, isVisible),
  );

  /// عقدة جديدة بقيم السجل ومعرّف حرّ، جاهزة للإفلات من المكتبة.
  static DesignNode newNode(
    DesignDocument document,
    AppPage page,
    String type, {
    String parentId = '',
  }) {
    final root = document.rootOf(page);
    final taken = root == null ? <String>{} : DesignTree.idsOf(root);
    return WidgetRegistry.node(type, DesignTree.freshId(taken, DesignTree.baseOf(type)));
  }
}
