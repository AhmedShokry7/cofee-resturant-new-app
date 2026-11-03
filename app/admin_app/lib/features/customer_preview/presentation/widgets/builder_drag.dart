import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';

/// ما يحمله سحب واحد: عنصر جديد من المكتبة، أو طبقة قائمة تُنقل.
///
/// النوع وحده يكفي للفحص، لكن النقل يحتاج معرّف المنقولة حتى لا تُحسب مؤشرات
/// الإفلات على قائمة فيها طبقة سيُخرجها الإفلات نفسه.
class BuilderDrag {
  const BuilderDrag({required this.type, this.existingId});

  /// نوع المكوّن المسجَّل، وهو ما يفحصه السجل قبل أي إفلات.
  final String type;

  /// معرّف الطبقة المنقولة، وnull يعني عنصرًا جديدًا من المكتبة.
  final String? existingId;

  bool get isMove => existingId != null;
}

/// موضع الإفلات في قائمة أبناء الأب بعد إخراج الطبقة المنقولة، وهو ما ترسمه
/// المؤشرات: السحب فوق نفسها لا يزيح أحدًا، وكل ما بعدها ينزل خانة حين تخرج.
int dropIndex({
  required BuilderDrag drag,
  required List<DesignNode> siblings,
  required int slotIndex,
}) {
  final existingId = drag.existingId;
  if (existingId == null) return slotIndex;
  final from = siblings.indexWhere((child) => child.id == existingId);
  return from >= 0 && from < slotIndex ? slotIndex - 1 : slotIndex;
}

/// هل يقبل هذا الأب هذا السحب؟ نفس فاحصات السجل التي يمشي عليها الـ cubit قبل
/// أن تلمس الشجرة، فلا يضيء مؤشر إفلات ثم تُرفض العملية في صمت.
DesignEditRejection rejectionOfDrop({
  required DesignDocument document,
  required AppPage page,
  required BuilderDrag drag,
  required String parentId,
}) {
  final existingId = drag.existingId;
  if (existingId == null) {
    return DesignDocumentEdit.attachRejection(
      document,
      page,
      parentId: parentId,
      childType: drag.type,
    );
  }
  final root = document.rootOf(page);
  if (root == null) return DesignEditRejection.missingNode;
  return DesignTree.rejectionOfMove(root, existingId, parentId);
}
