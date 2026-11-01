import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Which option values are currently chosen, keyed by group id.
///
/// Replaces the frozen `DrinkSize` / `SugarLevel` / `ProductExtra` enums. Those
/// could not express a category-specific extra list, a different set of sizes,
/// or a product with four groups instead of three, and they were hardcoded in
/// Dart so an admin adding an option had no effect on the app.
class OptionSelection {
  const OptionSelection(this._byGroup);

  const OptionSelection.empty() : _byGroup = const {};

  final Map<String, Set<String>> _byGroup;

  static OptionSelection defaultsFor(List<OptionGroup> groups) {
    final map = <String, Set<String>>{};
    for (final group in groups) {
      final defaults = group.values
          .where((v) => v.isDefault)
          .map((v) => v.id)
          .toSet();
      map[group.id] = defaults;
    }
    return OptionSelection(map);
  }

  /// Never returns null, so callers can treat a group with no selection as an
  /// empty set instead of handling a special case.
  Set<String> inGroup(String groupId) => _byGroup[groupId] ?? const <String>{};

  bool isSelected(String valueId) =>
      _byGroup.values.any((ids) => ids.contains(valueId));

  OptionValue? valueOf(List<OptionGroup> groups, String groupId) {
    for (final g in groups) {
      if (g.id != groupId) continue;
      for (final v in g.values) {
        if (inGroup(groupId).contains(v.id)) return v;
      }
    }
    return null;
  }

  /// Every selected value, flattened.
  List<OptionValue> selectedValues(List<OptionGroup> groups) => [
    for (final group in groups)
      for (final value in group.values)
        if (inGroup(group.id).contains(value.id)) value,
  ];

  /// Sum of the deltas. Used for the instant local price while the server
  /// confirms the authoritative one.
  double deltaOf(List<OptionGroup> groups) {
    var total = 0.0;
    for (final value in selectedValues(groups)) {
      total += value.priceDelta;
    }
    return total;
  }

  /// Flat list sent to resolvePrice, which takes option value ids.
  List<String> get valueIds => [for (final ids in _byGroup.values) ...ids];

  /// "Large, Less Sugar, Whipped Cream" for the cart note.
  ///
  /// The old note joined the Dart enum labels. This joins the database labels,
  /// so a renamed option shows its new name instead of the stale compiled one.
  String note(List<OptionGroup> groups) {
    return [
      for (final group in groups)
        for (final value in group.values)
          if (inGroup(group.id).contains(value.id)) value.name,
    ].join(', ');
  }

  /// True when the customer must pick more before adding to the cart.
  String? validationError(List<OptionGroup> groups) {
    for (final group in groups) {
      final count = inGroup(group.id).length;
      if (count < group.minSelect) return S.chooseOption(group.name);
      final max = group.maxSelect;
      if (max != null && count > max) return S.maxOption(max, group.name);
    }
    return null;
  }

  /// Applies a tap, honouring single-select, max-select and min-select.
  OptionSelection toggle(
    List<OptionGroup> groups,
    String groupId,
    String valueId,
  ) {
    final group = groups.firstWhere((g) => g.id == groupId);
    final next = {..._byGroup};
    final current = {...(next[groupId] ?? const <String>{})};

    if (group.isSingleSelect) {
      if (current.contains(valueId)) {
        // A required group keeps its value: tapping it again is a no-op rather
        // than an empty selection the customer cannot restore.
        if (group.minSelect == 0) current.clear();
      } else {
        current
          ..clear()
          ..add(valueId);
      }
    } else if (current.contains(valueId)) {
      // Deselecting must never drop below min_select.
      if (current.length > group.minSelect) current.remove(valueId);
    } else {
      final max = group.maxSelect;
      if (max == null || current.length < max) current.add(valueId);
    }

    next[groupId] = current;
    return OptionSelection(next);
  }

  bool get isEmpty => valueIds.isEmpty;

  Map<String, Set<String>> toMap() => Map.unmodifiable(_byGroup);
}

/// Size bucket for the cup illustration.
///
/// The art still only knows three cup shapes, so a size option is mapped onto
/// one of them by its code. Anything unrecognised renders at medium size
/// instead of crashing, which is what a new admin-defined size would otherwise
/// do to the screen.
enum CupSize {
  small(0.8),
  medium(1.0),
  large(1.22);

  const CupSize(this.scale);

  final double scale;

  static CupSize fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'small':
      case 's':
      case 'short':
        return CupSize.small;
      case 'large':
      case 'l':
      case 'tall':
        return CupSize.large;
      default:
        return CupSize.medium;
    }
  }
}

/// Cup size implied by the currently selected size group, if any.
CupSize cupSizeFor(List<OptionGroup> groups, OptionSelection selection) {
  for (final group in groups) {
    if (group.code != 'size') continue;
    for (final value in group.values) {
      if (selection.inGroup(group.id).contains(value.id)) {
        return CupSize.fromCode(value.code);
      }
    }
  }
  return CupSize.medium;
}

/// Local price before the server confirms it.
///
/// Kept as an estimate so tapping a chip updates the price on the same frame.
/// The authoritative figure comes from resolvePrice, which also accounts for a
/// branch price override that no client-side sum could know about.
double estimateUnitPrice(
  ProductModel product,
  List<OptionGroup> groups,
  OptionSelection selection,
) => product.price + selection.deltaOf(groups);
