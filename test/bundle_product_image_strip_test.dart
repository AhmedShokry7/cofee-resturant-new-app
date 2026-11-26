import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/presentation/views/bundle_product_image_strip.dart';

void main() {
  testWidgets('one-image bundle preview fits a ListTile leading slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListTile(
            leading: SizedBox(
              width: 48,
              child: BundleProductImageStrip(
                items: [
                  CustomerBundleItem(
                    id: 'one',
                    bundleId: 'bundle',
                    productId: 'product-one',
                    quantity: 1,
                    productImageUrl: 'https://example.test/one.png',
                  ),
                  CustomerBundleItem(
                    id: 'two',
                    bundleId: 'bundle',
                    productId: 'product-two',
                    quantity: 1,
                    productImageUrl: 'https://example.test/two.png',
                  ),
                ],
                imageSize: 48,
                maxImages: 1,
                showMoreCount: false,
              ),
            ),
            title: Text('Saved bundle'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
