import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:catalog_app/models/product.dart';
import 'package:catalog_app/providers/cart_provider.dart';
import 'package:catalog_app/providers/catalog_provider.dart';
import 'package:catalog_app/providers/order_provider.dart';
import 'package:catalog_app/models/order.dart';
import 'package:catalog_app/screens/cart_screen.dart';
import 'package:catalog_app/screens/catalog_screen.dart';
import 'package:catalog_app/screens/orders_history_screen.dart';
import 'package:catalog_app/widgets/product_card.dart';
import 'package:catalog_app/widgets/product_image_viewer.dart';

void main() {
  final products = <Product>[
    const Product(id: 1, name: 'منتج 1', description: 'وصف 1', image: ''),
    const Product(id: 2, name: 'منتج 2', description: 'وصف 2', image: ''),
    const Product(id: 3, name: 'منتج 3', description: 'وصف 3', image: ''),
  ];

  testWidgets('Image viewer supports swipe and quick add',
      (WidgetTester tester) async {
    final cart = CartProvider();
    cart.addProduct(products.first, quantity: 2);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showProductImageViewer(
                        context: context,
                        products: products,
                        initialIndex: 0,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('productImageViewerPageView')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    expect(find.byKey(const Key('productImageViewerInOrderQty')), findsOneWidget);
    expect(find.text('في الطلب: 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('productImageViewerAddButton')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(cart.getQuantity(1), 3);
    expect(find.text('في الطلب: 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('productImageViewerAddButton')));
    await tester.pumpAndSettle();
    expect(cart.getQuantity(1), 4);
    expect(find.text('في الطلب: 4'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const Key('productImageViewerPageView')),
      const Offset(-500, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('في الطلب: 0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('productImageViewerAddButton')));
    await tester.pumpAndSettle();

    expect(cart.getQuantity(2), 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Removing cart item requires confirmation',
      (WidgetTester tester) async {
    final cart = CartProvider();
    cart.addProduct(products.first);

    await tester.pumpWidget(
      ChangeNotifierProvider<CartProvider>.value(
        value: cart,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('منتج 1'), findsOneWidget);

    await tester.tap(find.text('إزالة'));
    await tester.pumpAndSettle();

    expect(find.text('هل أنت متأكد من إزالة هذا المنتج من الطلب؟'), findsOneWidget);
    expect(cart.getQuantity(1), 1);

    await tester.tap(find.text('إزالة').last);
    await tester.pumpAndSettle();

    expect(cart.isEmpty, isTrue);
    expect(find.text('لا توجد عناصر بعد'), findsOneWidget);
  });

  testWidgets('Product card image area is portrait friendly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: ProductCard(
                product: products.first,
                onTap: () {},
                onQuickAdd: () {},
                quantityInCart: 2,
              ),
            ),
          ),
        ),
      ),
    );

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(aspectRatio.aspectRatio, 3 / 4);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Catalog grid uses portrait and landscape density settings',
      (WidgetTester tester) async {
    final catalog = _FakeCatalogProvider(products);

    Future<void> pumpWithSize(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ],
          child: const MaterialApp(home: CatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWithSize(const Size(390, 844));
    final portraitGrid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    final portraitDelegate =
        portraitGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(portraitDelegate.crossAxisCount, 2);
    expect(portraitDelegate.childAspectRatio, 0.58);
    expect(portraitDelegate.crossAxisSpacing, 8);
    expect(portraitDelegate.mainAxisSpacing, 8);

    await pumpWithSize(const Size(900, 500));
    final landscapeGrid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    final landscapeDelegate =
        landscapeGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(landscapeDelegate.crossAxisCount, 3);
    expect(landscapeDelegate.childAspectRatio, 0.62);
    expect(landscapeDelegate.crossAxisSpacing, 8);
    expect(landscapeDelegate.mainAxisSpacing, 8);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Orders screen defaults to today and supports previous filter with totals',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final todayOrder = Order(
      id: 1,
      shopName: 'متجر اليوم',
      date: now,
      notes: 'ملاحظة',
    );
    final previousOrder = Order(
      id: 2,
      shopName: 'متجر سابق',
      date: now.subtract(const Duration(days: 2)),
      notes: null,
    );

    final provider = _FakeOrderProvider(
      orders: [todayOrder, previousOrder],
      summaries: {
        1: const OrderListSummary(
          itemCount: 3,
          total: 120,
          isTotalAvailable: true,
        ),
        2: const OrderListSummary(
          itemCount: 2,
          total: null,
          isTotalAvailable: false,
        ),
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: provider,
        child: const MaterialApp(home: OrdersHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('متجر اليوم'), findsOneWidget);
    expect(find.text('متجر سابق'), findsNothing);
    expect(find.text('المجموع: 120.00 ₪'), findsOneWidget);

    await tester.tap(find.textContaining('الطلبات السابقة'));
    await tester.pumpAndSettle();

    expect(find.text('متجر سابق'), findsOneWidget);
    expect(find.text('متجر اليوم'), findsNothing);
    expect(find.text('يوجد منتجات غير مسعّرة'), findsOneWidget);
  });
}

class _FakeCatalogProvider extends CatalogProvider {
  _FakeCatalogProvider(this._mockProducts);

  final List<Product> _mockProducts;

  @override
  List<Product> get products => _mockProducts;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadProducts({bool activeOnly = false}) async {}
}

class _FakeOrderProvider extends OrderProvider {
  _FakeOrderProvider({
    required List<Order> orders,
    required Map<int, OrderListSummary> summaries,
  })  : _mockOrders = orders,
        _summaries = summaries;

  final List<Order> _mockOrders;
  final Map<int, OrderListSummary> _summaries;

  @override
  List<Order> get orders => _mockOrders;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadOrders() async {}

  @override
  Future<OrderListSummary> getOrderListSummary(int orderId) async {
    return _summaries[orderId] ??
        const OrderListSummary(
          itemCount: 0,
          total: null,
          isTotalAvailable: false,
        );
  }
}
