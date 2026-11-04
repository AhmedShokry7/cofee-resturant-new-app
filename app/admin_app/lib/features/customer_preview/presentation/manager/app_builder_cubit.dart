import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_template.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/registry/template_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_state.dart';

/// محرّر تصميم تطبيق العميل: شجرة الصفحة، التحديد، التراجع، والحفظ والنشر.
///
/// لا قراءة بيانات هنا: ما تعرضه الشجرة يقرؤه [CustomerPreviewCubit] من عقود
/// صفحات الإدارة، فتبقى قاعدة واحدة للحالة وأخرى للمحتوى. المحرّر يملك المستند
/// وحده، وكل عملية تمرّ بفحص السجل قبل أن تلمس الشجرة — ما لا يُرسم لا يُضاف.
///
/// التراجع والـ Redo نسخ كاملة من المستند لا أفعال معكوسة: الشجرة ثابتة، فأي
/// عملية ترجع نسخة جديدة، والحفظ نسخة قبلها يكفي للتراجع عن أي عمق.
class AppBuilderCubit extends Cubit<AppBuilderState> {
  AppBuilderCubit({required this._repository}) : super(const AppBuilderState());

  /// أقصى ما يحتفظ المحرّر من خطوات رجوع: ذاكرة اللوحة ليست سجل المشروع.
  static const int historyDepth = 50;

  final AppBuilderRepository _repository;

  final List<DesignDocument> _past = <DesignDocument>[];
  final List<DesignDocument> _future = <DesignDocument>[];

  /// القراءة الجارية تُمنع بعلم خاص: الحالة الأولية «تحميل» قبل أي قراءة.
  bool _reading = false;

  Future<void> load() async {
    if (_reading) return;
    _reading = true;
    emit(
      state.copyWith(
        status: AppBuilderStatus.loading,
        clearError: true,
        isSaving: false,
        isPublishing: false,
      ),
    );
    try {
      // القراءات الثلاث مستقلّة، فتُبدأ قبل أن تُنتظر كما يفعل محاكي العميل،
      // ولكل واحدة سامع فورًا: لو سبق خطأ المسودة إلى الـ catch لظلت بقية
      // الأخطاء بلا مستمع يُطبع بعد أن تنطفئ الشاشة.
      final draftFuture = _repository.loadDraft();
      final publishedFuture = _repository.loadPublished();
      final versionsFuture = _repository.loadVersions();
      final draft = await _capture(draftFuture);
      final published = await _capture(publishedFuture);
      final versions = await _capture(versionsFuture);
      final failure = draft.error ?? published.error ?? versions.error;
      if (failure != null) throw failure;
      if (isClosed) return;

      emit(
        state.copyWith(
          status: AppBuilderStatus.ready,
          document: draft.value ?? published.value ?? WidgetRegistry.defaultDocument(),
          draftSaved: draft.value ?? published.value,
          clearDraftSaved: draft.value == null && published.value == null,
          published: published.value,
          clearPublished: published.value == null,
          versions: versions.value ?? const <DesignVersion>[],
          clearSelection: true,
          source: published.value == null ? AppBuilderSource.draft : state.source,
          canUndo: false,
          canRedo: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AppBuilderStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    } finally {
      _reading = false;
    }
  }

  // ---------- العرض: صفحة، ووضع،ومصدر ----------

  void openPage(AppPage page) {
    if (state.page == page) return;
    emit(state.copyWith(page: page, clearSelection: true));
  }

  void select(String? id) {
    if (state.selectedId == id) return;
    // التحديد مفهوم اللوحة لا الشاشة: في المشاهدة يعمل النقر كما عند الزبون
    // ولا يُحدَّد عنصر، فلا outlines ولا لوحة خصائص على ما لا يُحرَّر.
    if (state.isPreview) return;
    emit(state.copyWith(selectedId: id, clearSelection: id == null));
  }

  void setMode(AppBuilderMode mode) {
    // الخروج من المشاهدة لا يترك تحديدًا على عقدة قد لا تكون في المعروض.
    emit(state.copyWith(mode: mode, clearSelection: true));
  }

  void showSource(AppBuilderSource source) {
    if (source == AppBuilderSource.version && state.versionDocument == null) {
      return;
    }
    emit(state.copyWith(source: source, clearSelection: true));
  }

  // ---------- البناء ----------

  /// عنصر جديد من المكتبة، أو إفلاته على اللوحة. يرجع سبب الرفض حتى تُسمّيه
  /// اللوحة، ولا تلمس الشجرة حين لا رسم يقبله.
  DesignEditRejection insert({
    required String type,
    String? parentId,
    int? index,
  }) {
    final rejection = _editingRejection;
    if (rejection != DesignEditRejection.none) return rejection;
    final document = state.document;
    final root = document?.rootOf(state.page);
    if (document == null || root == null) {
      return DesignEditRejection.missingNode;
    }
    final to = parentId ?? root.id;
    final rejectionOfDrop = DesignDocumentEdit.attachRejection(
      document,
      state.page,
      parentId: to,
      childType: type,
    );
    if (rejectionOfDrop != DesignEditRejection.none) return rejectionOfDrop;

    final child = DesignDocumentEdit.newNode(document, state.page, type);
    final next = DesignDocumentEdit.insert(
      document,
      state.page,
      parentId: to,
      index: index ?? root.children.length,
      child: child,
    );
    _apply(next);
    select(child.id);
    return DesignEditRejection.none;
  }

  /// نقل عقدة داخل صفحتها أو بينها وبين الحاويات المسموحة. [index] يُحسب على
  /// قائمة الأبناء بعد إخراج المنقولة، وهو ما ترسمه مؤشرات الإفلات.
  DesignEditRejection move({
    required String id,
    required String newParentId,
    required int index,
  }) {
    final rejection = _editingRejection;
    if (rejection != DesignEditRejection.none) return rejection;
    final document = state.document;
    final root = document?.rootOf(state.page);
    if (document == null || root == null) return DesignEditRejection.missingNode;
    final refusal = DesignTree.rejectionOfMove(root, id, newParentId);
    if (refusal != DesignEditRejection.none) return refusal;
    _apply(DesignDocumentEdit.move(
      document,
      state.page,
      id: id,
      newParentId: newParentId,
      index: index,
    ));
    select(id);
    return DesignEditRejection.none;
  }

  DesignEditRejection remove(String id) {
    final rejection = _editingRejection;
    if (rejection != DesignEditRejection.none) return rejection;
    final document = state.document;
    final root = document?.rootOf(state.page);
    if (document == null || root == null) return DesignEditRejection.missingNode;
    final refusal = DesignTree.rejectionOfRemove(root, id);
    if (refusal != DesignEditRejection.none) return refusal;
    _apply(DesignDocumentEdit.remove(document, state.page, id));
    if (state.selectedId == id) select(null);
    return DesignEditRejection.none;
  }

  DesignEditRejection duplicate(String id) {
    final rejection = _editingRejection;
    if (rejection != DesignEditRejection.none) return rejection;
    final document = state.document;
    final root = document?.rootOf(state.page);
    if (document == null || root == null) return DesignEditRejection.missingNode;
    final source = DesignTree.find(root, id);
    if (source == null) return DesignEditRejection.missingNode;
    if (DesignTree.isLocked(source.type)) {
      return DesignEditRejection.lockedComponent;
    }
    // النسخة الجديدة هي المحددة: ما لا يُرى لا يُحرَّر. معرّفها مشتقّ من معرّف
    // الأصل لا من نوعه، وهو ما تولّده [DesignTree.duplicate] بالترتيب نفسه.
    final cloneId = DesignTree.freshId(DesignTree.idsOf(root), source.id);
    _apply(DesignDocumentEdit.duplicate(document, state.page, id));
    select(cloneId);
    return DesignEditRejection.none;
  }

  /// اسم جديد لطبقة في الشجرة: معرّف العقدة وحده. يرجع سبب الرفض حتى تُسمّيه
  /// اللوحة، والفحص في المستند كله لا في الصفحة وحدها.
  DesignEditRejection rename({required String id, required String newId}) {
    final rejection = _editingRejection;
    if (rejection != DesignEditRejection.none) return rejection;
    final document = state.document;
    if (document == null) return DesignEditRejection.missingNode;
    final refusal = DesignDocumentEdit.renameRejection(
      document,
      state.page,
      id,
      newId,
    );
    if (refusal != DesignEditRejection.none) return refusal;
    _apply(
      DesignDocumentEdit.rename(
        document,
        state.page,
        id: id,
        newId: newId.trim(),
      ),
    );
    // المحددة بعد التسمية هي المنطوقة باسمها الجديد، وإلا بقي التحديد على اسم
    // لم يعد في الشجرة.
    select(newId.trim());
    return DesignEditRejection.none;
  }

  DesignEditRejection toggleVisible(String id) {
    final rejection = _editingRejection;
    if (rejection != DesignEditRejection.none) return rejection;
    final document = state.document;
    final root = document?.rootOf(state.page);
    if (document == null || root == null) return DesignEditRejection.missingNode;
    final node = DesignTree.find(root, id);
    if (node == null) return DesignEditRejection.missingNode;
    if (DesignTree.isLocked(node.type)) {
      return DesignEditRejection.lockedComponent;
    }
    _apply(
      DesignDocumentEdit.setVisible(
        document,
        state.page,
        id: id,
        isVisible: !node.isVisible,
      ),
    );
    return DesignEditRejection.none;
  }

  /// سبب رفض القيمة، وnull يعني طُبّقت. الفحص هنا لا في اللوحة وحدها: خاصية
  /// خارج حدودها تصل إلى شاشة الزبون لو مرّت.
  String? setProperty({
    required String id,
    required String key,
    required Object? value,
  }) {
    if (_editingRejection != DesignEditRejection.none) return 'قراءة فقط';
    final document = state.document;
    if (document == null) return 'لا مستند';
    final spec = WidgetRegistry.of(
      DesignTree.find(document.rootOf(state.page)!, id)?.type ?? '',
    );
    final property = spec?.property(key);
    if (property == null) return 'خاصية لا يعرفها المكوّن';
    final reason = property.reject(value);
    if (reason != null) return reason;
    _apply(
      DesignDocumentEdit.setProperty(
        document,
        state.page,
        id: id,
        key: key,
        value: value,
      ),
    );
    return null;
  }

  // ---------- طبقة الشكل ----------

  /// لون دور عام. القيمة تُفحص هنا لا في اللوحة وحدها: `#GG` ناقص حرف يصل إلى
  /// ColorScheme عند الزبون فينقلب كل شيء إلى أسود.
  String? setThemeColor(DesignColorRole role, String hex) {
    if (_editingRejection != DesignEditRejection.none) return 'قراءة فقط';
    final document = state.document;
    if (document == null) return 'لا مستند';
    if (!DesignTheme.isHexColor(hex)) return 'لون بصيغة #RRGGBB مطلوب';
    _apply(document.withTheme(document.theme.withColor(role, hex.trim())));
    return null;
  }

  /// إرجاع دور إلى ما كان عليه قبل النظام: لا قيمة تُحفظ له، فيقرؤها العميل من
  /// نظام تصميمه. هذه هي «الرجوع للتصميم الأصلي» على مستوى لون واحد.
  void clearThemeColor(DesignColorRole role) {
    final document = state.document;
    if (document == null || _editingRejection != DesignEditRejection.none) {
      return;
    }
    if (!document.theme.colors.containsKey(role)) return;
    _apply(document.withTheme(document.theme.withoutColor(role)));
  }

  /// الطبقة كلها إلى الأصل: خطوة تراجع واحدة، لا دورًا دورًا. ما لا كتابة له
  /// يُقرأ من نظام تصميم العميل، فـ«التصميم الأصلي» حالة في المستند لا ذكرى في
  /// اللوحة.
  void clearTheme() {
    final document = state.document;
    if (document == null || _editingRejection != DesignEditRejection.none) {
      return;
    }
    if (!document.theme.isChanged) return;
    _apply(document.withTheme(DesignTheme.none));
  }

  /// مقياس الخط: لا رقم حرّ — المفتاح وحده يُخزَّن، والعميل يترجمه إلى مضاعف
  /// يعرفه هو، فلا تخترع اللوحة مقياسًا لا يقرؤه أحد.
  String? setThemeTextScale(String key) {
    return _setThemeScale(
      key,
      DesignScale.textKeys,
      (theme, value) => theme.withTextScale(value),
    );
  }

  String? setThemeRadiusScale(String key) {
    return _setThemeScale(
      key,
      DesignScale.radiusKeys,
      (theme, value) => theme.withRadiusScale(value),
    );
  }

  String? _setThemeScale(
    String key,
    Set<String> allowed,
    DesignTheme Function(DesignTheme, String) apply,
  ) {
    if (_editingRejection != DesignEditRejection.none) return 'قراءة فقط';
    final document = state.document;
    if (document == null) return 'لا مستند';
    if (!allowed.contains(key)) return 'مقياس غير مسموح';
    _apply(document.withTheme(apply(document.theme, key)));
    return null;
  }

  // ---------- التراجع والـ Redo ----------

  void undo() {
    if (_past.isEmpty || state.document == null) return;
    final previous = _past.removeLast();
    _future.add(state.document!);
    if (_future.length > historyDepth) _future.removeAt(0);
    emit(
      state.copyWith(
        document: previous,
        canUndo: _past.isNotEmpty,
        canRedo: _future.isNotEmpty,
        clearSelection: !_holdsNode(previous, state.selectedId),
      ),
    );
  }

  void redo() {
    if (_future.isEmpty || state.document == null) return;
    final next = _future.removeLast();
    _past.add(state.document!);
    if (_past.length > historyDepth) _past.removeAt(0);
    emit(
      state.copyWith(
        document: next,
        canUndo: _past.isNotEmpty,
        canRedo: _future.isNotEmpty,
        clearSelection: !_holdsNode(next, state.selectedId),
      ),
    );
  }

  // ---------- الحفظ والنشر والإصدارات ----------

  /// حفظ المسودة: لا شيء منها يصل إلى الزبون، فلا حاجة أن تكون صالحة للنشر.
  Future<bool> saveDraft() async {
    final document = state.document;
    if (document == null || state.isSaving) return false;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.saveDraft(document);
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false, draftSaved: document));
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: adminErrorMessage(error),
        ),
      );
      return false;
    }
  }

  /// النشر ممتنع على شجرة لا تُرسم؛ القاعدة ترفض هي الأخرى، وهذا الرفض هنا
  /// يمنع جولة شبكة تعرف اللوحة نتائجها سلفًا.
  Future<bool> publish() async {
    final document = state.document;
    if (document == null || state.isPublishing) return false;
    final validation = state.validation;
    if (validation == null || !validation.isPublishable) return false;
    emit(state.copyWith(isPublishing: true, clearError: true));
    try {
      final version = await _repository.publish(document);
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPublishing: false,
          published: document,
          versions: <DesignVersion>[version, ...state.versions],
          draftSaved: document,
          source: AppBuilderSource.published,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPublishing: false,
          errorMessage: adminErrorMessage(error),
        ),
      );
      return false;
    }
  }

  Future<void> refreshVersions() async {
    try {
      final versions = await _repository.loadVersions();
      if (isClosed) return;
      emit(state.copyWith(versions: versions));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  /// أسماء ما حفظه الموظف من قوالب، لا ملفّاتها: القائمة تُفتح على أسماء،
  /// والمستند يُسحب فقط حين يقرّر أحد أن يفتحه.
  Future<void> refreshTemplates() async {
    try {
      final templates = await _repository.loadTemplates();
      if (isClosed) return;
      emit(state.copyWith(templates: templates));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  /// قالب مضمّن على المستند الحالي: ترتيب وألوان، ومقاطع الموظف التي لا
  /// يعرفها القالب تبقى كما هي. تراجع عنه زرّ التراجع نفسه.
  void applyBuiltInTemplate(AppTemplate template) {
    final document = state.document;
    if (document == null) {
      emit(state.copyWith(errorMessage: S.builderNoDocument));
      return;
    }
    final next = template.applyTo(document);
    // مرتان من نفس القالب عدلان واحد: لا طابور تراجع بعِدْل لا يغيّر حرفًا،
    // كما تفعل طبقة الشكل مع دورٍ لم يُلْمَس.
    if (next.hasSameContent(document)) return;
    _apply(next);
  }

  /// فتح قالب محفوظ محلّ المستند الحالي. لا نشر ضمنًا: القالب يدخل المسودة،
  /// والزبون لا يرى شيئًا حتى يضغط الموظف «نشر».
  Future<void> applySavedTemplate(String templateId) async {
    try {
      final document = await _repository.loadTemplate(templateId);
      if (isClosed) return;
      if (document == null || state.document == null) {
        emit(state.copyWith(errorMessage: S.builderTemplateMissing));
        return;
      }
      _apply(document);
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  /// حفظ ما على الشاشة كقالب. ترفض القاعدة مستندًا لا يُنشر، فلا يقعد في
  /// المعرض قالب يعطب عند النشر.
  Future<bool> saveTemplate(String name) async {
    final document = state.document;
    if (document == null) {
      emit(state.copyWith(errorMessage: S.builderNoDocument));
      return false;
    }
    emit(state.copyWith(clearError: true));
    try {
      final saved = await _repository.saveTemplate(name, document);
      if (isClosed) return false;
      emit(
        state.copyWith(
          templates: <DesignTemplate>[saved, ...state.templates],
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
      return false;
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      await _repository.deleteTemplate(templateId);
      if (isClosed) return;
      emit(
        state.copyWith(
          templates: state.templates
              .where((template) => template.id != templateId)
              .toList(growable: false),
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  /// استعراض إصدار داخل الهاتف دون المساس بالمسودة.
  Future<void> inspectVersion(String versionId) async {
    try {
      final document = await _repository.loadVersion(versionId);
      if (isClosed) return;
      if (document == null) {
        emit(state.copyWith(errorMessage: S.builderVersionMissing));
        return;
      }
      emit(
        state.copyWith(
          versionDocument: document,
          source: AppBuilderSource.version,
          clearSelection: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  /// الرجوع إعادة نشر برقم جديد: السجل لا يُمحى، والموظف يرى أنه رجع لا أنه عدّل.
  Future<bool> restoreVersion(String versionId) async {
    if (state.isPublishing) return false;
    emit(state.copyWith(isPublishing: true, clearError: true));
    try {
      final version = await _repository.restoreVersion(versionId);
      if (isClosed) return false;
      final published = await _repository.loadPublished();
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPublishing: false,
          published: published,
          clearPublished: published == null,
          versions: <DesignVersion>[version, ...state.versions],
          source: AppBuilderSource.published,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPublishing: false,
          errorMessage: adminErrorMessage(error),
        ),
      );
      return false;
    }
  }

  /// تجاهل ما لم يُحفظ والرجوع إلى المنشور.
  Future<void> discardDraft() async {
    final published = state.published;
    emit(state.copyWith(clearError: true));
    try {
      await _repository.discardDraft();
      if (isClosed) return;
      emit(
        state.copyWith(
          document: published ?? WidgetRegistry.defaultDocument(),
          draftSaved: published,
          clearDraftSaved: published == null,
          source: AppBuilderSource.draft,
          clearSelection: true,
          canUndo: false,
          canRedo: false,
        ),
      );
      _past.clear();
      _future.clear();
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: adminErrorMessage(error)));
    }
  }

  // ---------- خاص ----------

  /// قراءة مستقلّة تُرجع قيمتها أو خطأها في نفس الوقت، حتى يكون لكل قراءة started
  /// مبكرًا سامعٌ يستهلك خطأها في مكانه. أول خطأ يصل يبقى وحده صاحب القرار في
  /// حالة الشاشة، لأن بقية الأخطاء استُهلكت هنا ولا تُطبع فوقه.
  Future<({T? value, Object? error})> _capture<T>(Future<T> read) async {
    try {
      return (value: await read, error: null);
    } catch (error) {
      return (value: null, error: error);
    }
  }

  DesignEditRejection get _editingRejection =>
      state.isPreview ? DesignEditRejection.previewMode : DesignEditRejection.none;

  void _apply(DesignDocument next) {
    final current = state.document;
    if (current == null) return;
    _past.add(current);
    if (_past.length > historyDepth) _past.removeAt(0);
    _future.clear();
    emit(
      state.copyWith(document: next, canUndo: true, canRedo: false),
    );
  }

  bool _holdsNode(DesignDocument document, String? id) {
    if (id == null) return false;
    final root = document.rootOf(state.page);
    return root != null && DesignTree.find(root, id) != null;
  }
}
