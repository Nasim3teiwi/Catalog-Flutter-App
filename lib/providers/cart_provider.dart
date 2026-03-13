import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};

  Map<int, CartItem> get items => Map.unmodifiable(_items);
  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);
  int get distinctItemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  double get totalPrice {
    return _items.values.fold(0.0, (sum, item) {
      return sum + (item.productPrice ?? 0) * item.quantity;
    });
  }

  void addProduct(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items[product.id!]!.quantity += quantity;
    } else {
      _items[product.id!] = CartItem(
        productId: product.id!,
        productName: product.name,
        productImage: product.image,
        productPrice: product.price,
        quantity: quantity,
      );
    }
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    if (!_items.containsKey(productId)) return;
    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      _items[productId]!.quantity = quantity;
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  int getQuantity(int productId) {
    return _items[productId]?.quantity ?? 0;
  }
}
