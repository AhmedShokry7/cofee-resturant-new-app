import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';

void main() {
  group('AdminSearchController', () {
    late AdminSearchController controller;

    setUp(() {
      controller = AdminSearchController();
    });

    test('update stores the trimmed query and notifies the bound handler', () {
      final seen = <String>[];
      controller.bind(seen.add);

      controller.update('  latte  ');

      expect(controller.query, 'latte');
      expect(controller.hasQuery, isTrue);
      expect(seen, ['latte']);
    });

    test('update ignores a query that did not change', () {
      final seen = <String>[];
      controller.bind(seen.add);

      controller.update('latte');
      controller.update('latte');

      expect(seen, ['latte']);
    });

    test('clear resets the query and notifies the bound handler', () {
      final seen = <String>[];
      controller.bind(seen.add);

      controller.update('latte');
      controller.clear();

      expect(controller.query, isEmpty);
      expect(controller.hasQuery, isFalse);
      expect(seen, ['latte', '']);
    });

    test('bind replaces the previous handler', () {
      final first = <String>[];
      final second = <String>[];
      controller.bind(first.add);
      controller.bind(second.add);

      controller.update('mocha');

      expect(first, isEmpty);
      expect(second, ['mocha']);
    });
  });
}
