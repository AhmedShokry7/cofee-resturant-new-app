import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_phrases.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';

/// Canonical variant values (English internally, localized on display).
class OrderVariants {
  const OrderVariants._();

  static const sizes = {'small', 'medium', 'large'};
  static const sugars = {'none', 'less', 'normal', 'extra'};

  static const Map<String, String> sizeWords = {
    'صغير': 'small',
    'صغيره': 'small',
    'سمول': 'small',
    'small': 'small',
    'وسط': 'medium',
    'ميديم': 'medium',
    'متوسط': 'medium',
    'medium': 'medium',
    'ميديام': 'medium',
    'كبير': 'large',
    'كبيره': 'large',
    'جامبو': 'large',
    'large': 'large',
    'لارج': 'large',
  };

  static const Map<String, String> sugarPhrases = {
    'من غير سكر': 'none', 'لا سكر': 'none', 'بدون': 'none',
    'بدون سكر': 'none',
    'منغير سكر': 'none',
    'no sugar': 'none',
    'zero sugar': 'none',
    'سكر قليل': 'less',
    'سكر خفيف': 'less',
    'سكر اقل': 'less',
    'قليل السكر': 'less',
    'سكر شوي': 'less',
    'شوي سكر': 'less',
    'less sugar': 'less',
    'سكر زيادة': 'extra',
    'زياده سكر': 'extra',
    'زيادة سكر': 'extra',
    'سكر كتير': 'extra',
    'سكر واجد': 'extra',
    'سكر وايد': 'extra',
    'extra sugar': 'extra',
    'مظبوط': 'normal',
    'مظبوطه': 'normal',
    'مضبوط': 'normal',
    'سكر وسط': 'normal',
    'سكر عادي': 'normal',
    'عادي': 'normal',
  };

  static const Map<String, int> numberWords = {
    'واحد': 1,
    'واحده': 1,
    'اتنين': 2,
    'اثنين': 2,
    'ثنين': 2,
    'تلاته': 3,
    'ثلاثه': 3,
    'اربعه': 4,
    'أربعه': 4,
    'خمسه': 5,
    'سته': 6,
    'سبعه': 7,
    'تمانيه': 8,
    'ثمانيه': 8,
    'تسعه': 9,
    'عشره': 10,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
  };

  static String sizeLabel(String size, {required bool arabic}) {
    if (!arabic) return size;
    return switch (size) {
      'small' => 'صغير',
      'medium' => 'وسط',
      _ => 'كبير',
    };
  }

  static String? sizeFromQuery(String query) {
    final n = normalizeText(query);
    String? found;
    for (final entry in sizeWords.entries) {
      if (n.contains(normalizeText(entry.key))) found = entry.value;
    }
    return found;
  }

  static String? sugarFromQuery(String query) {
    final n = normalizeText(query);
    // Longer phrases first.
    final entries = sugarPhrases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in entries) {
      if (n.contains(normalizeText(entry.key))) return entry.value;
    }
    return null;
  }

  static String sugarLabel(String sugar, {required bool arabic}) {
    if (!arabic) return '$sugar sugar';
    return switch (sugar) {
      'none' => 'من غير سكر',
      'less' => 'سكر قليل',
      'extra' => 'سكر زيادة',
      _ => 'مظبوط',
    };
  }
}

/// One line of a conversational order.
class OrderDraftItem {
  OrderDraftItem({
    required this.productId,
    this.quantity = 1,
    this.size,
    this.sugar,
  });

  final String productId;
  final int quantity;
  final String? size;
  final String? sugar;

  String variantNote({required bool arabic}) {
    final parts = <String>[];
    if (size != null) {
      parts.add(OrderVariants.sizeLabel(size!, arabic: arabic));
    }
    if (sugar != null) {
      parts.add(OrderVariants.sugarLabel(sugar!, arabic: arabic));
    }
    return parts.join(arabic ? '، ' : ', ');
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    if (size != null) 'size': size,
    if (sugar != null) 'sugar': sugar,
  };

  static OrderDraftItem? fromJson(dynamic value) {
    if (value is! Map) return null;
    try {
      final id = value['productId']?.toString();
      if (id == null || id.isEmpty) return null;
      return OrderDraftItem(
        productId: id,
        quantity: (value['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1,
        size: value['size']?.toString(),
        sugar: value['sugar']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The in-progress conversational order (the "draft").
class OrderDraft {
  OrderDraft([List<OrderDraftItem>? items]) : items = items ?? [];

  final List<OrderDraftItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  void updateLast({String? size, String? sugar}) {
    if (items.isEmpty) return;
    final last = items.removeLast();
    items.add(
      OrderDraftItem(
        productId: last.productId,
        quantity: last.quantity,
        size: size ?? last.size,
        sugar: sugar ?? last.sugar,
      ),
    );
  }

  void add(OrderDraftItem item) {
    for (var i = 0; i < items.length; i++) {
      final existing = items[i];
      if (existing.productId == item.productId &&
          existing.size == item.size &&
          existing.sugar == item.sugar) {
        items[i] = OrderDraftItem(
          productId: existing.productId,
          quantity: (existing.quantity + item.quantity).clamp(1, 99),
          size: existing.size,
          sugar: existing.sugar,
        );
        return;
      }
    }
    items.add(item);
  }

  double total() {
    final snapshot = AssistantSnapshot.current;
    var sum = 0.0;
    for (final item in items) {
      sum += snapshot.estimatedUnitPriceFor(item) * item.quantity;
    }
    return sum;
  }

  /// "2x Latte (large, less sugar) + 1x Cheesecake (small)".
  String describe({required bool arabic}) {
    final snapshot = AssistantSnapshot.current;
    final parts = <String>[];
    for (final item in items) {
      final product = snapshot.productById(item.productId);
      final name = product?.name ?? item.productId;
      final note = snapshot.variantNoteFor(item, arabic: arabic);
      parts.add('${item.quantity}x $name${note.isEmpty ? '' : ' ($note)'}');
    }
    return parts.join(' + ');
  }

  List<Map<String, dynamic>> toJson() =>
      items.map((item) => item.toJson()).toList();

  static OrderDraft fromJson(dynamic value) {
    if (value is! List) return OrderDraft();
    return OrderDraft(
      value.map(OrderDraftItem.fromJson).whereType<OrderDraftItem>().toList(),
    );
  }
}

/// Result of parsing an order message.
class ParsedOrder {
  ParsedOrder({
    required this.items,
    this.unclearDessert = false,
    this.unclearSize,
  });

  final List<OrderDraftItem> items;

  /// True when the message wants "something sweet" without naming it.
  final bool unclearDessert;

  /// Size mentioned without a product ("وطبق حلو صغير").
  final String? unclearSize;
}

/// Parses "2 لاتيه كبير سكر قليل و تشيز كيك" into structured items.
/// Pure Dart, unit-testable.
ParsedOrder parseOrderMessage(String query) {
  final normalized = normalizeText(query);
  if (normalized.isEmpty) {
    return ParsedOrder(items: const []);
  }
  final menu = AssistantSnapshot.current.products;
  String? idOfName(String name) {
    for (final product in menu) {
      if (normalizeText(AssistantSnapshot.canonicalName(product)) == name) {
        return product.id;
      }
    }
    return null;
  }

  // Product mentions with positions (whole words only).
  final spots = <int, String>{};
  void addMention(String phrase, String id) {
    final norm = normalizeText(phrase);
    if (norm.length < 3) return;
    var index = normalized.indexOf(norm);
    while (index >= 0) {
      if (_wholeWord(normalized, index, norm.length)) {
        spots.putIfAbsent(index, () => id);
      }
      index = normalized.indexOf(norm, index + 1);
    }
  }

  for (final product in menu) {
    final canonical = AssistantSnapshot.canonicalName(product);
    addMention(canonical, product.id);
    if (product.name != canonical) addMention(product.name, product.id);
  }
  for (final entry in AssistantPhrases.productSynonyms.entries) {
    final id = idOfName(normalizeText(entry.value));
    if (id != null) addMention(entry.key, id);
  }
  // Generic "coffee" maps to nothing specific — needs clarification later.
  final ordered = spots.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final items = <OrderDraftItem>[];
  for (var i = 0; i < ordered.length; i++) {
    final start = i == 0 ? 0 : ordered[i - 1].key;
    final end = i + 1 < ordered.length
        ? ordered[i + 1].key
        : normalized.length;
    final window = normalized.substring(start, end);
    items.add(
      OrderDraftItem(
        productId: ordered[i].value,
        quantity: _quantityIn(window, ordered[i].key - start),
        size: _sizeIn(window),
        sugar: _sugarIn(window),
      ),
    );
  }

  // Generic sweet craving without a named product.
  var unclearDessert = false;
  String? unclearSize;
  if (ordered.isEmpty ||
      !_hasDessertCategory(items.map((item) => item.productId))) {
    for (final marker in _dessertGenerics) {
      if (_containsWord(normalized, marker)) {
        unclearDessert = true;
        break;
      }
    }
    if (unclearDessert) {
      // Size floating without a product ("وطبق حلو صغير").
      for (final entry in OrderVariants.sizeWords.entries) {
        if (_containsWord(normalized, normalizeText(entry.key))) {
          unclearSize = entry.value;
          break;
        }
      }
    }
  }
  return ParsedOrder(
    items: items,
    unclearDessert: unclearDessert,
    unclearSize: unclearSize,
  );
}

bool _wholeWord(String text, int index, int length) {
  final beforeOk = index == 0 || text[index - 1] == ' ';
  final end = index + length;
  final afterOk = end >= text.length || text[end] == ' ';
  return beforeOk && afterOk;
}

bool _containsWord(String normalized, String word) {
  final norm = normalizeText(word);
  if (norm.length < 3) return norm.isNotEmpty && normalized == norm;
  var index = normalized.indexOf(norm);
  while (index >= 0) {
    if (_wholeWord(normalized, index, norm.length)) return true;
    index = normalized.indexOf(norm, index + 1);
  }
  return false;
}

bool _hasDessertCategory(Iterable<String> ids) {
  const sweetCats = {'desserts', 'snacks', 'bakery', 'donuts'};
  final menu = AssistantSnapshot.current.products;
  for (final id in ids) {
    for (final product in menu) {
      if (product.id == id &&
          sweetCats.contains(AssistantSnapshot.categoryKey(product))) {
        return true;
      }
    }
  }
  return false;
}

const List<String> _dessertGenerics = [
  'حلو', 'حلا', 'حلويات', 'ديزيرت', 'كيك', 'cake', 'dessert', 'sweet dish',
  'سناك', 'تسالي', 'طبق حلو', 'حاجه حلوه', 'حاجة حلوة',
];

int _quantityIn(String window, int mentionOffset) {
  int? best;
  var bestDist = 1 << 30;
  void consider(int value, int pos) {
    final dist = (pos - mentionOffset).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = value;
    }
  }

  final tokens = window.split(' ');
  var cursor = 0;
  for (final token in tokens) {
    final pos = window.indexOf(token, cursor);
    cursor = pos + token.length;
    final digits = int.tryParse(token);
    if (digits != null && digits > 0 && digits <= 99) {
      consider(digits, pos);
      continue;
    }
    final word = OrderVariants.numberWords[token];
    if (word != null) consider(word, pos);
  }
  return best ?? 1;
}

String? _sizeIn(String window) {
  for (final entry in OrderVariants.sizeWords.entries) {
    if (_containsWord(window, entry.key)) return entry.value;
  }
  return null;
}

String? _sugarIn(String window) {
  // Longer phrases first ("من غير سكر" before bare words).
  final entries = OrderVariants.sugarPhrases.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in entries) {
    if (_containsWord(window, entry.key)) return entry.value;
  }
  return null;
}
