import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_option_group_cubit.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_page_actions.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_pickable_list.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// يفتح حوار إنشاء مجموعة أحجام أو إضافات جديدة.
Future<void> showOptionGroupCreateDialog({
  required BuildContext context,
  required AdminOptionGroupCubit cubit,
  required List<AdminProduct> products,
  required List<AdminCategory> categories,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => OptionGroupDataDialog(
      onSave: cubit.createGroup,
      products: products,
      categories: categories,
    ),
  );
}

/// يفتح حوار تعديل مجموعة قائمة، بقيمها ونطاقها كما حفظتها القاعدة.
Future<void> showOptionGroupEditDialog({
  required BuildContext context,
  required AdminOptionGroupCubit cubit,
  required AdminOptionGroup group,
  required List<AdminProduct> products,
  required List<AdminCategory> categories,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => OptionGroupDataDialog(
      initialGroup: group,
      onSave: cubit.updateGroup,
      products: products,
      categories: categories,
    ),
  );
}

/// سطر قيمة واحدة أثناء الكتابة: المعرّف إن كان محفوظًا، وأرباع نصّ تتحكّم
/// بنفسها حتى لا يُعاد بناؤها مع كل ضغطة زرّ في الحقل.
class _ValueDraft {
  _ValueDraft({
    this.id = '',
    String nameAr = '',
    String nameEn = '',
    String code = '',
    double priceDelta = 0,
    this.isDefault = false,
    this.isActive = true,
  }) : nameArController = TextEditingController(text: nameAr),
       nameEnController = TextEditingController(text: nameEn),
       codeController = TextEditingController(text: code),
       priceController = TextEditingController(
         text: priceDelta == 0 ? '' : _trimNumber(priceDelta),
       );

  factory _ValueDraft.of(AdminOptionValue value) => _ValueDraft(
    id: value.id,
    nameAr: value.nameAr,
    nameEn: value.nameEn,
    code: value.code,
    priceDelta: value.priceDelta,
    isDefault: value.isDefault,
    isActive: value.isActive,
  );

  /// '' للقيمة الجديدة، فالقاعدة هي التي تمنحها معرّفها.
  final String id;
  final TextEditingController nameArController;
  final TextEditingController nameEnController;
  final TextEditingController codeController;
  final TextEditingController priceController;
  bool isDefault;
  bool isActive;

  void dispose() {
    nameArController.dispose();
    nameEnController.dispose();
    codeController.dispose();
    priceController.dispose();
  }

  static String _trimNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

class OptionGroupDataDialog extends StatefulWidget {
  const OptionGroupDataDialog({
    super.key,
    required this.onSave,
    required this.products,
    required this.categories,
    this.initialGroup,
  });

  final Future<void> Function(AdminOptionGroup group) onSave;
  final AdminOptionGroup? initialGroup;

  /// الكتالوج الذي يُنتقى منه النطاق، كما يقرأه الكيوبت لا كما تحمله البطاقة.
  final List<AdminProduct> products;
  final List<AdminCategory> categories;

  @override
  State<OptionGroupDataDialog> createState() => _OptionGroupDataDialogState();
}

class _OptionGroupDataDialogState extends State<OptionGroupDataDialog> {
  /// `^[a-z_]+$` كما يشترطه عمود `code` في 008 للمجموعة.
  static final RegExp _groupCodePattern = RegExp(r'^[a-z_]+$');

  /// `^[a-z0-9_]+$` كما يشترطه العمود نفسه لقيمة المجموعة.
  static final RegExp _valueCodePattern = RegExp(r'^[a-z0-9_]+$');

  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _codeController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _minSelectController;
  late final TextEditingController _maxSelectController;

  late final List<_ValueDraft> _drafts;

  /// المنتقيات تُستبدل كاملة عند كل ضغطة (`AdminPickableList.onChanged` يمنح
  /// مجموعة جديدة)، فهي `late` بلا `final`: الأخير يأذن بتعيين واحد بعد
  /// `initState` ثم يرمي `LateInitializationError` على أول منتج ينتقيه الأدمن.
  late Set<String> _categoryIds;
  late Set<String> _productIds;
  late Set<String> _excludedProductIds;

  late AdminOptionSelectionType _selectionType;
  late AdminOptionGroupScope _scope;
  late bool _isRequired;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _nameArController = TextEditingController(text: group?.nameAr ?? '');
    _nameEnController = TextEditingController(text: group?.nameEn ?? '');
    _codeController = TextEditingController(text: group?.code ?? '');
    _sortOrderController = TextEditingController(
      text: (group?.sortOrder ?? 0).toString(),
    );
    _minSelectController = TextEditingController(
      text: (group?.minSelect ?? 0) == 0 ? '' : '${group?.minSelect}',
    );
    _maxSelectController = TextEditingController(
      text: group?.maxSelect == null ? '' : '${group?.maxSelect}',
    );
    _selectionType = group?.selectionType ?? AdminOptionSelectionType.single;
    _scope = group?.scope ?? AdminOptionGroupScope.products;
    _isRequired = group?.isRequired ?? false;
    _drafts = (group?.values ?? const <AdminOptionValue>[])
        .map(_ValueDraft.of)
        .toList();
    if (_drafts.isEmpty) _drafts.add(_ValueDraft());
    _categoryIds = <String>{...?group?.categoryIds};
    _productIds = <String>{...?group?.productIds};
    _excludedProductIds = <String>{...?group?.excludedProductIds};
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _codeController.dispose();
    _sortOrderController.dispose();
    _minSelectController.dispose();
    _maxSelectController.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  bool get _isSingle => _selectionType == AdminOptionSelectionType.single;

  /// الأدنى كما سيُكتب، لا كما كُتب في الحقل: الاختيار الواحد لا سقفَ فوقه
  /// عندها (ck_option_groups_single) والإلزام يعني واحدًا على الأقل
  /// (ck_option_groups_required)، فاللوحة تشتقّ الرقم بدل أن ترفضه القاعدة
  /// بشيفرة 23514 بعد ضغطة الحفظ.
  int get _minSelectValue {
    final typed = parseLocalizedInt(_minSelectController.text) ?? 0;
    if (_isSingle) return _isRequired ? 1 : 0;
    return _isRequired && typed < 1 ? 1 : typed;
  }

  Future<void> _save() async {
    if (_saving) return;
    final failure = _validate();
    if (failure != null) {
      setState(() => _error = failure);
      return;
    }

    // سقف الاختيار الواحد واحد عند القاعدة، وبلا مجموعة واحدة يبقى بلا سقف.
    final maxSelect = _isSingle
        ? 1
        : parseLocalizedInt(_maxSelectController.text);

    final group =
        (widget.initialGroup ??
                const AdminOptionGroup(code: '', nameAr: '', nameEn: ''))
            .copyWith(
              code: _codeController.text.trim(),
              nameAr: _nameArController.text.trim(),
              nameEn: _nameEnController.text.trim().isEmpty
                  ? _nameArController.text.trim()
                  : _nameEnController.text.trim(),
              selectionType: _selectionType,
              minSelect: _minSelectValue,
              maxSelect: maxSelect,
              isRequired: _isRequired,
              sortOrder: parseLocalizedInt(_sortOrderController.text) ?? 0,
              scope: _scope,
              categoryIds: _scope == AdminOptionGroupScope.category
                  ? _categoryIds.toList(growable: false)
                  : const <String>[],
              productIds: _scope == AdminOptionGroupScope.products
                  ? _productIds.toList(growable: false)
                  : const <String>[],
              excludedProductIds: _scope == AdminOptionGroupScope.products
                  ? const <String>[]
                  : _excludedProductIds.toList(growable: false),
              values: _values(),
            );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(group);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = adminErrorMessage(error, reasons: optionGroupRefusalReasons());
      });
    }
  }

  List<AdminOptionValue> _values() {
    final rows = _drafts;
    return <AdminOptionValue>[
      for (var index = 0; index < rows.length; index++)
        AdminOptionValue(
          id: rows[index].id,
          code: rows[index].codeController.text.trim(),
          nameAr: rows[index].nameArController.text.trim(),
          nameEn: rows[index].nameEnController.text.trim().isEmpty
              ? rows[index].nameArController.text.trim()
              : rows[index].nameEnController.text.trim(),
          priceDelta:
              parseLocalizedNumber(rows[index].priceController.text) ?? 0,
          sortOrder: index,
          isDefault: rows[index].isDefault,
          isActive: rows[index].isActive,
        ),
    ];
  }

  /// يعيد جملة الخطأ أول ما يجد سببًا، أو null حين يصحّ كل شيء.
  ///
  /// الفحص يسير كما تسير الأقسام على الشاشة — بيانات ثم كيف يختار ثم النطاق ثم
  /// الخيارات — فالبانر يشير إلى أول ما يمكن للأدمن إصلاحه بالأعلى، لا إلى سطر
  /// مخفيّ تحت الحقل الصحيح.
  String? _validate() {
    if (_nameArController.text.trim().isEmpty) return S.nameRequired;
    final code = _codeController.text.trim();
    if (code.isEmpty || !_groupCodePattern.hasMatch(code)) {
      return S.invalidOptionCode;
    }

    if (!_isSingle) {
      // العدد الأدنى هو المشتقّ الذي سيُكتب، فلا يُقارن به سقفٌ على رقمٍ لم
      // يُكتب: إلزام مع صفر مرفوع إلى واحد قبل الحفظ.
      final min = _minSelectValue;
      if (min < 0) return S.invalidNumber;
      final maxText = _maxSelectController.text.trim();
      if (maxText.isNotEmpty) {
        final max = parseLocalizedInt(maxText);
        if (max == null || max < 1 || max < min) return S.invalidNumber;
      }
    }

    // نطاق بلا هدف معناه مجموعة تُحفظ ولا يراها أحد: دالة الحلّ في 224 لا
    // تختار منها شيئًا، فلا يُترك الحفظ ليكتشف الأدمن ذلك عند العميل.
    if (_scope == AdminOptionGroupScope.category && _categoryIds.isEmpty) {
      return S.scopeNeedsCategories;
    }
    if (_scope == AdminOptionGroupScope.products && _productIds.isEmpty) {
      return S.scopeNeedsProducts;
    }

    if (_drafts.length < 2 && widget.initialGroup == null) {
      // مجموعة بحجم واحد لا تقرر شيئًا: «صغير» وحده ليس اختيارًا يطرحه العميل.
      return S.noOptionValuesYet;
    }

    final seenCodes = <String>{};
    for (var index = 0; index < _drafts.length; index++) {
      final draft = _drafts[index];
      if (draft.nameArController.text.trim().isEmpty) {
        return localizeDigits(S.optionValueNeedsName(index + 1));
      }
      final valueCode = draft.codeController.text.trim();
      if (valueCode.isEmpty || !_valueCodePattern.hasMatch(valueCode)) {
        return S.invalidOptionCode;
      }
      if (!seenCodes.add(valueCode)) return S.duplicateOptionCode;
      final priceText = draft.priceController.text.trim();
      if (priceText.isNotEmpty && parseLocalizedNumber(priceText) == null) {
        return S.invalidNumber;
      }
    }

    return null;
  }

  void _addDraft() {
    setState(() {
      _drafts.add(_ValueDraft());
      _error = null;
    });
  }

  void _removeDraft(int index) {
    setState(() {
      _drafts.removeAt(index).dispose();
      _error = null;
    });
  }

  /// خيار افتراضي واحد فقط: العميل يفتح صفحة مشروب على حالة واحدة لا على
  /// حالتين متنافستين.
  void _makeDefault(int index) {
    setState(() {
      for (var i = 0; i < _drafts.length; i++) {
        _drafts[i].isDefault = i == index;
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .9, 800.0);

    return Dialog(
      key: const Key('option-group-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < AppBreakpoints.pageCanvas
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: widget.initialGroup == null
                    ? S.newOptionGroup
                    : S.editOptionGroup,
                onClose: _saving ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AdminErrorBanner(message: _error!),
                        const SizedBox(height: AppSizes.px14),
                      ],
                      _section(S.optionGroupIdentitySection, [
                        _twoFields(
                          _field(
                            key: const Key('option-group-name-ar'),
                            controller: _nameArController,
                            label: '${S.name} (${S.arabicLabel})',
                            hint: S.optionValueNameHint,
                            required: true,
                            rtl: true,
                          ),
                          _field(
                            key: const Key('option-group-name-en'),
                            controller: _nameEnController,
                            label: '${S.name} (${S.englishLabel})',
                            hint: S.optionValueNameHint,
                          ),
                        ),
                        const SizedBox(height: AppSizes.px10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _field(
                                key: const Key('option-group-code'),
                                controller: _codeController,
                                label: S.optionCodeLabel,
                                hint: S.optionCodeHint,
                                required: true,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _field(
                                key: const Key('option-group-sort'),
                                controller: _sortOrderController,
                                label: S.sortOrder,
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ]),
                      _section(S.selectionTypeSection, [
                        AdminSegmentedControl(
                          options: <String>[
                            S.singleChoiceLabel,
                            S.multipleChoicesLabel,
                          ],
                          selected: _isSingle
                              ? S.singleChoiceLabel
                              : S.multipleChoicesLabel,
                          onChanged: (value) => setState(() {
                            _selectionType = value == S.singleChoiceLabel
                                ? AdminOptionSelectionType.single
                                : AdminOptionSelectionType.multiple;
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: AppSizes.px10),
                        SwitchListTile(
                          key: const Key('option-group-required'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _isRequired,
                          title: Text(
                            S.requiredGroupLabel,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size11,
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _isRequired = value),
                        ),
                        if (!_isSingle) ...[
                          const SizedBox(height: AppSizes.px4),
                          _twoFields(
                            _field(
                              key: const Key('option-group-min'),
                              controller: _minSelectController,
                              label: S.requiredChoicesLabel,
                              hint: '0',
                              keyboardType: TextInputType.number,
                              helper: _isRequired
                                  ? S.requiredChoicesHelper
                                  : null,
                            ),
                            _field(
                              key: const Key('option-group-max'),
                              controller: _maxSelectController,
                              label: S.maximumChoicesLabel,
                              hint: S.maximumChoicesHint,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ]),
                      _section(S.scopeSection, [
                        AdminSegmentedControl(
                          options: <String>[
                            S.scopeAllProducts,
                            S.scopeCategories,
                            S.scopeProducts,
                          ],
                          selected: switch (_scope) {
                            AdminOptionGroupScope.all => S.scopeAllProducts,
                            AdminOptionGroupScope.category => S.scopeCategories,
                            AdminOptionGroupScope.products => S.scopeProducts,
                          },
                          onChanged: (value) => setState(() {
                            _scope = switch (value) {
                              _ when value == S.scopeAllProducts =>
                                AdminOptionGroupScope.all,
                              _ when value == S.scopeCategories =>
                                AdminOptionGroupScope.category,
                              _ => AdminOptionGroupScope.products,
                            };
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: AppSizes.px8),
                        _helper(S.scopeHelper),
                        if (_scope == AdminOptionGroupScope.category) ...[
                          const SizedBox(height: AppSizes.px8),
                          AdminPickableList(
                            title: S.pickCategoriesTitle,
                            items: [
                              for (final category in widget.categories)
                                AdminPickableItem(
                                  id: category.id,
                                  name: category.nameAr.trim().isEmpty
                                      ? category.nameEn
                                      : category.nameAr,
                                  caption: S.productsCount(
                                    category.productCount,
                                  ),
                                  isActive: category.isActive,
                                ),
                            ],
                            selectedIds: _categoryIds,
                            onChanged: (next) =>
                                setState(() => _categoryIds = next),
                          ),
                        ],
                        if (_scope == AdminOptionGroupScope.products) ...[
                          const SizedBox(height: AppSizes.px8),
                          AdminPickableList(
                            title: S.pickProductsTitle,
                            items: _productItems,
                            selectedIds: _productIds,
                            onChanged: (next) =>
                                setState(() => _productIds = next),
                          ),
                        ],
                        if (_scope != AdminOptionGroupScope.products) ...[
                          const SizedBox(height: AppSizes.px8),
                          AdminPickableList(
                            title: S.excludedProductsTitle,
                            items: _productItems,
                            selectedIds: _excludedProductIds,
                            onChanged: (next) =>
                                setState(() => _excludedProductIds = next),
                          ),
                          _helper(S.excludedProductsHelper),
                        ],
                      ]),
                      _section(S.optionValuesSection, [
                        for (var index = 0; index < _drafts.length; index++)
                          _valueRow(index),
                        const SizedBox(height: AppSizes.px8),
                        Row(
                          children: [
                            TextButton.icon(
                              key: const Key('option-group-add-value'),
                              onPressed: _addDraft,
                              icon: const Icon(AppIcons.add01, size: 16),
                              label: Text(S.addOptionValue),
                            ),
                            const Spacer(),
                            Text(
                              localizeDigits(
                                S.optionValuesCount(_drafts.length),
                              ),
                              style: TextStyle(
                                color: adminMutedColor(theme),
                                fontSize: AppFontSizes.size9_5,
                              ),
                            ),
                          ],
                        ),
                        _helper(S.priceDeltaHelper),
                      ]),
                    ],
                  ),
                ),
              ),
              AdminDialogFooter(
                saving: _saving,
                onCancel: () => Navigator.of(context).pop(),
                onSave: _save,
                saveKey: const Key('option-group-save'),
                saveLabel: S.save,
                savingLabel: S.save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AdminPickableItem> get _productItems => [
    for (final product in widget.products)
      AdminPickableItem(
        id: product.id,
        name: product.nameAr.trim().isEmpty ? product.nameEn : product.nameAr,
        caption: product.categoryNameAr ?? product.sku,
        isActive: product.isActive,
      ),
  ];

  Widget _valueRow(int index) {
    final theme = Theme.of(context);
    final draft = _drafts[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.px10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _field(
                  key: Key('option-value-code-$index'),
                  controller: draft.codeController,
                  label: S.optionCodeLabel,
                  hint: 'large',
                  required: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: _field(
                  key: Key('option-value-name-ar-$index'),
                  controller: draft.nameArController,
                  label: '${S.name} (${S.arabicLabel})',
                  hint: S.optionValueNameHint,
                  required: true,
                  rtl: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: _field(
                  key: Key('option-value-name-en-$index'),
                  controller: draft.nameEnController,
                  label: '${S.name} (${S.englishLabel})',
                  hint: S.optionValueNameHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px6),
          Row(
            children: [
              Expanded(
                child: _field(
                  key: Key('option-value-price-$index'),
                  controller: draft.priceController,
                  label: S.priceDeltaLabel,
                  hint: S.priceDeltaHint,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffix: const CurrencyIcon(size: 10),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                key: Key('option-value-default-$index'),
                onTap: () => _makeDefault(index),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: draft.isDefault,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (_) => _makeDefault(index),
                      ),
                      Text(
                        S.defaultChoiceLabel,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size10_5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: Key('option-value-remove-$index'),
                tooltip: S.delete,
                icon: const Icon(
                  AppIcons.delete01,
                  size: 18,
                  color: AppColor.errorColor,
                ),
                onPressed: _drafts.length > 1
                    ? () => _removeDraft(index)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _twoFields(Widget first, Widget second) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: second),
    ],
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    bool rtl = false,
    TextInputType? keyboardType,
    Widget? suffix,

    /// سطر تحت الحقل حين يكون ما يُحفظ غير ما كُتب فيه، حتى لا تكذب اللوحة
    /// على رقمٍ تشتقّه القاعدة.
    String? helper,
  }) {
    return TextField(
      key: key,
      controller: controller,
      textDirection: rtl ? TextDirection.rtl : null,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: AppFontSizes.size11),
      decoration:
          adminDialogFieldDecoration(
            context,
            label: label,
            hint: hint,
            required: required,
          ).copyWith(
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 34),
            helperText: helper,
            helperStyle: TextStyle(
              color: adminMutedColor(Theme.of(context)),
              fontSize: AppFontSizes.size9,
            ),
          ),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
    );
  }

  Widget _section(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: adminHeadingColor(theme),
            fontSize: AppFontSizes.size11,
            fontWeight: AppFontWeights.bold,
            height: AppTextHeights.line1_5,
          ),
        ),
        const SizedBox(height: AppSizes.px10),
        ...children,
        const SizedBox(height: AppSizes.px8),
        Divider(height: 1, color: adminRowBorderColor(theme)),
        const SizedBox(height: AppSizes.px14),
      ],
    );
  }

  Widget _helper(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
      child: Text(
        text,
        style: TextStyle(
          color: adminMutedColor(Theme.of(context)),
          fontSize: AppFontSizes.size9,
          height: AppTextHeights.line1_5,
        ),
      ),
    );
  }
}
